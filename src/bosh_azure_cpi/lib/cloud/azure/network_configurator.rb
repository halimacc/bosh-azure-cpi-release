module Bosh::AzureCloud
  ##
  # Represents Azure instance network config.
  #
  # VM can have up to 1 vip network attached to it.
  #
  # VM can have multiple private networks attached to it.
  # The VM size determines the number of NICs that you can create for a VM, please refer to
  # https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-sizes/ for the max number of NICs for different VM size.
  # When there are multiple private netowrks, you must have and only have 1 primary network specified. @networks[0] will be picked as the primary network.
  #

  class NetworkConfigurator
    include Helpers

    attr_reader :vip_network, :networks
    attr_accessor :logger

    ##
    # Creates new network spec
    #
    # @param [Hash] spec raw network spec passed by director
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "`#{spec.class}' provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @networks = []
      @vip_network = nil

      primary_networks = []
      secondary_networks = []

      logger.debug ("networks: `#{spec}'")
      spec.each_pair do |name, network_spec|

        network = nil
        network_type = network_spec["type"] || "manual"

        case network_type
          when "dynamic"
            network = DynamicNetwork.new(name, network_spec)

          when "manual"
            network = ManualNetwork.new(name, network_spec)

          when "vip"
            network = VipNetwork.new(name, network_spec)
            cloud_error("More than one vip network for `#{name}'") if @vip_network
            @vip_network = network

          else
            cloud_error("Invalid network type `#{network_type}' for Azure, " \
                        "can only handle `dynamic', `vip', or `manual' network types")
        end

        if network_type == "dynamic" || network_type == "manual"
          if network.primary == true
            primary_networks.push(network)
          else
            secondary_networks.push(network)
          end
        end
      end

      if primary_networks.size > 1
        cloud_error("Only one primary network is allowed")
      end

      if primary_networks.size == 0 && secondary_networks.size > 1
        cloud_error("Primary network must be defined for multiple networks")
      end

      @networks = primary_networks + secondary_networks

      if @networks.empty?
        cloud_error("At least one dynamic or manual network must be defined")
      end
    end

    def default_dns
      dns = nil
      @networks.each do |network|
        unless network.cloud_properties.nil? || network.cloud_properties["default"].nil?
          if network.cloud_properties["default"].include? "dns"
            dns = network.cloud_properties["dns"] unless network.cloud_properties["dns"].nil?
            return dns
          end
        end
      end
      dns
    end
  end
end
