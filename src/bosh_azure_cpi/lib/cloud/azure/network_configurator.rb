module Bosh::AzureCloud
  ##
  # Represents Azure instance network config.
  #
  # VM can have up to 1 vip network attached to it.
  #
  # VM can have multiple network interfaces attached to it.
  # The VM size determines the number of NICs that you can create for a VM, please refer to
  # https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-sizes/ for the max number of NICs for different VM size.
  # When there are multiple netowrks, you must have and only have 1 primary network specified. @networks[0] will be picked as the primary network.
  #

  class NetworkConfigurator
    include Helpers

    attr_reader :vip_network, :networks
    attr_accessor :logger

    ##
    # Creates new network spec
    #
    # @param [Hash] azure_properties global azure properties
    # @param [Hash] spec raw network spec passed by director
    def initialize(azure_properties, spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "`#{spec.class}' provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @azure_properties = azure_properties
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
            network = DynamicNetwork.new(@azure_properties, name, network_spec)

          when "manual"
            network = ManualNetwork.new(@azure_properties, name, network_spec)

          when "vip"
            network = VipNetwork.new(@azure_properties, name, network_spec)
            cloud_error("More than one vip network for `#{name}'") if @vip_network
            @vip_network = network

          else
            cloud_error("Invalid network type `#{network_type}' for Azure, " \
                        "can only handle `dynamic', `vip', or `manual' network types")
        end

        # For multiple networks, bosh will require (only) 1 default `dns' and (only) 1 default `gateway'.
        # The network with default `gateway' (primary_networks[0]) will be the primary network.
        #
        # For single network, primary_networks can be empty because `default' is not required,
        # in this case primary_networks[0] or secondary_networks[0] can be the primary network.
        #
        if network_type == "dynamic" || network_type == "manual"
          if network.has_default_gateway?
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

      # Make sure @networks[0] is the primary network
      @networks = primary_networks + secondary_networks

      if @networks.empty?
        cloud_error("At least one dynamic or manual network must be defined")
      end
    end

    # For multiple networks, use the default dns specified in spec.
    # For single network, use its dns anyway.
    #
    def default_dns
      @networks.each do |network|
        return network.spec["dns"] if network.has_default_dns?
      end
      @networks[0].spec["dns"]
    end
  end
end
