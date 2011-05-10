module PuppetRelationships
    require 'facter'
    require 'rubygems'
    require 'rgl/adjacency'
    require 'rgl/dot'
    require 'yaml'
    require 'json'
    
    def graph_from_dotfile(file, directed=true)
    #Creates a directed or undirected RGL object from 
    #a dot source file.
        g = directed ? RGL::DirectedAdjacencyGraph.new : RGL::AdjacencyGraph.new
        pattern = /\s*([^\"]+)[\"\s]*--[\"\s]*([^\"\[\;]+)/
        IO.foreach(file) do |line|
            case line
            when /^digraph/
                g = RGL::DirectedAdjacencyGraph.new
                pattern = /\s*([^\"]+)[\"\s]*->[\"\s]*([^\"\[\;]+)/
            when /"(.*)" \[/
                g.add_vertex $1
            when pattern
                g.add_edge $1,$2
            else
                nil
            end
        end 
        return g 
    end

    class GraphSender
    #Sender class implements the parsing of the puppet catalog,
    #the dot files generated on puppet runs and our simple_graph hack
    #to create an all inclusive hash that we can use to deliver json.
        attr_accessor :host, :resources, :edges, :external_edges, :file_path, :graph, :relationships

        def initialize(path)
            @file_path = (path =~ /.*\/$/) ? path.chop : path
            @graph = graph_from_dotfile("#{@file_path}/relationships.dot", true)
            @host = get_host
            @resources = get_resources
            @edges = get_edges
            @external_edges = get_external_edges
            @relationships = get_relationships
        end

        def to_json
            JSON.dump "#{@host}" => {:resources => @resources,
                                :edges => @edges,
                                :external_edges => @external_edges,
                                :relationships => @relationships}
        end

        def send
            raise "Not implemented"
        end

        private 

        def get_host
            Facter.value 'fqdn'
        end

        def get_resources
        #Node specific resources defined in relationships.dot
           tmp = []
           @graph.each_vertex do |resource|
               tmp << resource
           end
           tmp.sort
        end

        def get_edges
        #Resource-to-resource relationships internal to the node
            edges = {}
            @graph.each_vertex do |resource|
                tmp = []
                @graph.each_adjacent(resource) do |edge|
                    tmp << edge
                end
                edges[resource] = tmp
            end
            edges
        end

        def get_external_edges
        #Resource-to-resource relationships external to the node
            external_edges = {}
            edge_lines= File.open("#{@file_path}/frompuppet.txt").readlines 
            edge_lines.each do |line|
               external_edges[line.split(":")[0]] = line.split(":")[1].chop
            end
            external_edges
        end

        def get_relationships
        #Instances of the relationship type with sugar 
        #to determine cross-node relationship type and which host
        #and resource the mapping points at.
            relations = {}
            catalog = YAML.load_file("#{@file_path}/#{@host}.yaml")
            catalog["edges"].each do |edge|
                if edge.ivars["target"].ivars["type"] == "Relationship"
                    relations["Relationship[#{edge.ivars["target"].ivars["title"]}]"] = {
                        :host => edge.ivars["target"].ivars["parameters"][:host],
                        :relationship_type => edge.ivars["target"].ivars["parameters"][:relationship_type],
                        :related_resource => edge.ivars["target"].ivars["parameters"][:related_resource],
                        :related_host => edge.ivars["target"].ivars["parameters"][:related_host]
                     }
                end
            end
            relations
        end

    end

    class GraphReceiver
    #Receiver class implements fetching a message from our ActiveMQ
    #middleware and writing the json to a mongo, or some other yet
    #undecided database
        attr_accessor :json, :json_hash

        def initialize(json)
            #Recreating json for testing purposes. Object will 
            #later be fetched from ActiveMQ
            @json = json
        end

        def to_h
            JSON.parse json
        end

        def recieve
        #Fetches the json message from the middleware
            raise "Not Implemented"
        end

        def write
        #Write json to db
            raise "Not Implemented"
        end
    end

    class GraphProcessor
    #Initial implementation to show off our ability to recreate
    #graph objects from json and to identify nodes and relationships.
        
        attr_accessor :graph, :graph_hash

        def initialize(json) 
            @graph = graph_from_json(json)
        end

        def dependencies(resource)
        #Returns a list of all resources dependencies
            result = []
            @graph.each_adjacent(resource) do |edge|
                result << edge
            end
            result                
        end

        def has_external_relationship?(resource)
        #Returns true if resource has external dependencies
            dependencies(resource).each do |dep|
                if dep =~ /(.*):(.*):(.*)/
                    return true
                end
            end
            return false
        end

        def external_dependencies(resource)
        #Returns a hash of containing all external dependencies
            result = []
            dependencies(resource).each do |dep|
                if dep =~ /(.*):(.*):(.*)/
                    result << {:resource => $1, :host => $2, :type => $3}
                end
            end
            result
        end

        def resource_to_host(resource)
        #Returns a list of all resources that have external node dependencies
            result = []
            dependencies(resource).each do |dep|
                if dep =~ /(.*):(.*):(.*)/
                    result <<  $2
                end
            end    
            result        
        end

        def resource_to_resource(resource)
            result = []
            dependencies(resource).each do |dep|
                if dep =~ /(.*):(.*):(.*)/
                    result <<  $1
                end
            end    
            result        
        end

        def has_resource?(resource)
            @graph.has_vertex? resource
        end 

        private
        def graph_from_json(json)
        #Recreate the graph structure from json. In our test case
        #the json is directly sent by creating a sender object.
            @graph_hash = JSON.load json
            graph = RGL::DirectedAdjacencyGraph.new
            root = @graph_hash.keys.first
            graph.add_vertex root                                   #Create Root node, the name of the puppet node
            @graph_hash[root]["resources"].each do |vertex|                 #Create the graph nodes
                graph.add_vertex vertex
                graph.add_edge vertex, root      
            end
            @graph_hash[root]["edges"].each do |edge|                       #Create the connecting edges
                if @graph_hash[root]["external_edges"].include? edge[0]     #Check if relationship is to an external node
                    if @graph_hash[root]["relationships"].keys.include? @graph_hash[root]["external_edges"][edge[0]]
                        relationship = @graph_hash[root]["relationships"][@graph_hash[root]["external_edges"][edge[0]]]
                        graph.add_edge edge[0], "#{relationship["related_resource"]}:#{relationship["related_host"]}:#{relationship["relationship_type"]}"
                    end
                else
                    graph.add_edge edge[0], edge[1]                 #If not, create internal inter resource relationship
                end
            end 
            graph
        end
    end
end


#Conceptual tests showing off what we're able to do with PuppetRelationships::

include PuppetRelationships
require 'pp'

#sender1 represents client side creation of a graph object. 
sender1  = GraphSender.new("/home/psy/code/graphjunk/dev3")
#graph represents a server(?) side object ready for parsing and decision making.
graph  = GraphProcessor.new(sender1.to_json)

#List all dependencies that the node has
pp graph.dependencies("File[/srv/www/intranet.dev3.pinetecltd.net/current]")
#["dev3.pinetecltd.net", "Service[Nagios]:foo.bar:depends"]

#Check if node has external dependencies
puts graph.has_external_relationship?("File[/srv/www/intranet.dev3.pinetecltd.net/current]")
#true

#List the external dependencies of the node
pp graph.external_dependencies("File[/srv/www/intranet.dev3.pinetecltd.net/current]")
#[{:type=>"depends", :resource=>"Service[Nagios]", :host=>"foo.bar"}]

#List the external host dependencies
pp graph.resource_to_host("File[/srv/www/intranet.dev3.pinetecltd.net/current]")
#["foo.bar"]

#List the external resource dependencies
pp graph.resource_to_resource("File[/srv/www/intranet.dev3.pinetecltd.net/current]")
#["Service[Nagios]"]

#Check if relationship between 2 cross node resources can exist
sender2  = GraphSender.new("/home/psy/code/graphjunk/dev4")
graph2  = GraphProcessor.new(sender2.to_json)
graph.resource_to_resource("File[/srv/www/intranet.dev3.pinetecltd.net/current]").each do |res|
    unless graph2.has_resource?(res)
        puts "Graph 2 does not contain resource #{res}. Relationship is invalid."
    else
        puts "Relationship between resources is valid."
    end
end
#Graph 2 does not contain resource Service[Nagios]. Relationship is invalid.

sender2  = GraphSender.new("/home/psy/code/graphjunk/dev5")
graph2  = GraphProcessor.new(sender2.to_json)
graph.resource_to_resource("File[/srv/www/intranet.dev3.pinetecltd.net/current]").each do |res|
    unless graph2.has_resource?(res)
        puts "Graph 2 does not contain resource #{res}. Relationship is invalid."
    else
        puts "Relationship between File[/srv/www/intranet.dev3.pinetecltd.net/current] and #{res} is valid."
    end
end
#Relationship between File[/srv/www/intranet.dev3.pinetecltd.net/current] and Service[Nagios] is valid
