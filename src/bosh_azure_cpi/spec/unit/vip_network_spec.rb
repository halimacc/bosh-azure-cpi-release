require "spec_helper"

describe Bosh::AzureCloud::VipNetwork do
  let(:azure_properties) { mock_azure_properties }

  describe "everything is fine" do
    let(:network_spec) {
      {
        "type" => "vip",
        "ip"=>"fake-vip",
        "cloud_properties" => {}
      }
    }


    it "should get ip with right value" do
      nc = Bosh::AzureCloud::VipNetwork.new(azure_properties, "vip", network_spec)
      expect(nc.public_ip).to eq("fake-vip")
    end

    it "should get resource_group_name from global azure properties when resource_group_name is not specifed in cloud_properties" do
      nc = Bosh::AzureCloud::VipNetwork.new(azure_properties, "vip", network_spec)
      expect(nc.resource_group_name).to eq(azure_properties["resource_group_name"])
    end

    context "when having resource_group_name in cloud_properties" do
      let(:network_spec) {
        {
          "type" => "vip",
          "ip"=>"fake-vip",
          "cloud_properties" => {
            "resource_group_name" => "foo"
          }
        }
      }

      it "should return resource_group_name cloud_properties" do
        nc = Bosh::AzureCloud::VipNetwork.new(azure_properties, "vip", network_spec)
        expect(nc.resource_group_name).to eq("foo")
      end
    end
  end
end
