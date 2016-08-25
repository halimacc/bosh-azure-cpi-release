require "spec_helper"

describe Bosh::AzureCloud::NetworkConfigurator do

  let(:azure_properties) { mock_azure_properties }
  let(:dynamic) {
    {
      "type" => "dynamic",
      "default" => ["dns", "gateway"],
      "dns" => ["8.8.8.8"],
      "cloud_properties" =>
        {
          "subnet_name" => "bar",
          "virtual_network_name" => "foo"
        }
    }
  }
  let(:manual) {
    {
      "type" => "manual",
      "dns" => ["9.9.9.9"],
      "ip"=>"fake-ip",
      "cloud_properties" =>
        {
          "resource_group_name" => "fake-rg",
          "subnet_name" => "bar",
          "virtual_network_name" => "foo",
          "security_group" => "fake-nsg"
        }
    }
  }
  let(:vip) {
    {
      "type" => "vip"
    }
  }

  context "when spec isn't a hash" do
    it "should raise an error" do
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new("foo")
      }.to raise_error ArgumentError
    end
  end

  context "when network type is manual" do
    it "should create a ManualNetwork instance" do
      network_spec = {
        "network1" => manual
      }
      nc = Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
      expect(nc.networks.length).to eq(1)
      expect(nc.networks[0]).to be_a Bosh::AzureCloud::ManualNetwork
    end
  end

  context "when network type is dynamic" do
    it "should create a DynamicNetwork instance" do
      network_spec = {
        "network1" => dynamic
      }
      nc = Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
      expect(nc.networks.length).to eq(1)
      expect(nc.networks[0]).to be_a Bosh::AzureCloud::DynamicNetwork
    end
  end

  context "when network has vip configured" do
    it "should create a VipNetwork instance" do
      network_spec = {
        "network1" => manual,
        "network2" => vip
      }
      nc = Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
      expect(nc.vip_network).to be_a Bosh::AzureCloud::VipNetwork
      expect(nc.networks.length).to eq(1)
    end
  end

  context "when network spec has 2 networks (dynamic and manual) defined" do
    it "should return 2 for length of @networks" do
      network_spec = {
        "network1" => dynamic,
        "network2" => manual
      }
      nc = Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
      expect(nc.networks.length).to eq(2)
    end
  end

  context "when neither dynamic nor manual network is defined" do
    it "should raise an error" do
      network_spec = {
        "network1" => vip,
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "At least one dynamic or manual network must be defined"
    end
  end

  context "when multiple vip networks are defined" do
    it "should raise an error" do
      network_spec = {
        "network1" => vip,
        "network2" => vip
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "More than one vip network for `network2'"
    end
  end

  context "when an illegal network type is used" do
    it "should raise an error" do
      network_spec = {
        "network1" => {"type" => "foo"}
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "Invalid network type `foo' for Azure, " \
                        "can only handle `dynamic', `vip', or `manual' network types"
    end
  end

  describe "#default_dns" do
    context "when there are multiple networks" do
      it "should return dns from the network which has default dns defined" do
        network_spec = {
          "network1" => manual,
          "network2" => dynamic
        }
        nc = Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
        expect(nc.default_dns).to eq(['8.8.8.8'])
      end
    end

    context "when there is only 1 network" do
      it "should return dns from the network anyway" do
        network_spec = {
          "network1" => manual
        }
        nc = Bosh::AzureCloud::NetworkConfigurator.new(azure_properties, network_spec)
        expect(nc.default_dns).to eq(['9.9.9.9'])
      end
    end
  end
end
