require "spec_helper"

describe Bosh::AzureCloud::DynamicNetwork do
  let(:azure_properties) { mock_azure_properties }
  let(:network_spec) {{}}

  context "when everything is fine" do
    let(:network_spec) {
      {
        "default" => ["dns", "gateway"],
        "cloud_properties"=>{
          "virtual_network_name"=>"foo",
          "subnet_name"=>"bar",
          "resource_group_name" => "fake_resource_group",
          "security_group" => "fake_sg"
        }
      }
    }

    it "should return properties with right values" do
      sn = Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)

      expect(sn.resource_group_name).to eq("fake_resource_group")
      expect(sn.virtual_network_name).to eq("foo")
      expect(sn.subnet_name).to eq("bar")
      expect(sn.security_group).to eq("fake_sg")
      expect(sn.has_default_dns?).to eq(true)
      expect(sn.has_default_gateway?).to eq(true)
    end
  end

  context "when missing some required properties" do
    context "missing cloud_properties" do
      let(:network_spec) {
        {
          "fake-key" => "fake-value"
        }
      }

      it "should raise an error" do
          expect {
            Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
          }.to raise_error(/cloud_properties required for dynamic network/)
      end
    end

    context "missing virtual_network_name" do
      context "missing virtual_network_name" do
        let(:network_spec) {
          {
            "cloud_properties"=>{
              "subnet_name"=>"bar"
            }
          }
        }

        it "should raise an error" do
            expect {
              Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
            }.to raise_error(/virtual_network_name required for dynamic network/)
        end
      end

      context "virtual_network_name is nil" do
        let(:network_spec) {
          {
            "cloud_properties"=>{
              "virtual_network_name"=>nil,
              "subnet_name"=>"bar"
            }
          }
        }

        it "should raise an error" do
            expect {
              Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
            }.to raise_error(/virtual_network_name required for dynamic network/)
        end
      end
    end

    context "missing subnet_name" do
      context "missing subnet_name" do
        let(:network_spec) {
          {
            "cloud_properties"=>{
              "virtual_network_name"=>"foo"
            }
          }
        }

        it "should raise an error" do
            expect {
              Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
            }.to raise_error(/subnet_name required for dynamic network/)
        end
      end

      context "subnet_name is nil" do
        let(:network_spec) {
          {
            "cloud_properties"=>{
              "virtual_network_name"=>"foo",
              "subnet_name"=>nil
            }
          }
        }

        it "should raise an error" do
            expect {
              Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
            }.to raise_error(/subnet_name required for dynamic network/)
        end
      end
    end

    context "missing security_group" do
      let(:network_spec) {
        {
          "ip" => "fake-ip",
          "cloud_properties"=>{
            "virtual_network_name"=>"foo",
            "subnet_name"=>"bar"
          }
        }
      }

      it "should return nil for security_group" do
        sn = Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
        expect(sn.security_group).to eq(nil)
      end
    end

    context "missing resource_group_name" do
      let(:network_spec) {
        {
          "ip" => "fake-ip",
          "cloud_properties"=>{
            "virtual_network_name"=>"foo",
            "subnet_name"=>"bar"
          }
        }
      }

      it "should return resource_group_name from global azure properties" do
        sn = Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
        expect(sn.resource_group_name).to eq(azure_properties["resource_group_name"])
      end
    end

    context "missing default dns and gateway" do
      let(:network_spec) {
        {
          "ip" => "fake-ip",
          "cloud_properties"=>{
            "virtual_network_name"=>"foo",
            "subnet_name"=>"bar"
          }
        }
      }

      it "should return false for #has_default_dns?" do
        sn = Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
        expect(sn.has_default_dns?).to eq(false)
      end

      it "should return false for #has_default_gateway?" do
        sn = Bosh::AzureCloud::DynamicNetwork.new(azure_properties, "default", network_spec)
        expect(sn.has_default_dns?).to eq(false)
      end
    end
  end
end
