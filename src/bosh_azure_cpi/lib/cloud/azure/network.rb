module Bosh::AzureCloud
  class Network

    attr_reader :resource_group_name

    # {
    # "bosh"=>{"netmask"=>nil, "gateway"=>nil, "ip"=>"10.0.0.4", "dns"=>["168.63.129.16"], "type"=>"manual", "default"=>["dns", "gateway"], "cloud_properties"=>{"resource_group_name"=>"rg-name", "virtual_network_name"=>"boshvnet", "subnet_name"=>"Bosh", "security_group"=>"nsg-bosh"}},
    # "vip"=>{"ip"=>"23.101.15.75", "type"=>"vip", "cloud_properties"=>{"resource_group_name"=>"rg-name"}}
    #}

    ##
    # Creates a new network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "#{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger

      @name = name
      @ip = spec["ip"]
      @cloud_properties = spec["cloud_properties"]
      @spec = spec
      @resource_group_name = @cloud_properties.nil? ? nil : @cloud_properties["resource_group_name"]
    end
    
    def cloud_properties
      @cloud_properties
    end
  end
end
