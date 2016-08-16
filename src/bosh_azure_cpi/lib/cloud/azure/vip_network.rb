module Bosh::AzureCloud

  class VipNetwork < Network

    ##
    # Creates a new vip network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
      
      @resource_group_name = @cloud_properties["resource_group_name"] unless @cloud_properties.nil?
    end

    def public_ip
      @ip
    end

  end
end
