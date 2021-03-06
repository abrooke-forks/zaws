require 'json'
require 'netaddr'
require 'timeout'

module ZAWS
  module Services
    module EC2
      class Compute

        def initialize(shellout, aws,undofile)
          @shellout=shellout
          @aws=aws
          @undofile=undofile
          @undofile ||= ZAWS::Helper::ZFile.new
        end

        def view(region, viewtype, textout=nil, verbose=nil, vpcid=nil, externalid=nil,profile=nil,home=nil)
          # comline="aws --output #{viewtype} --region #{region} ec2 describe-instances"
          # if vpcid || externalid
          #   comline = comline + " --filter"
          # end
          # comline = comline + " \"Name=vpc-id,Values=#{vpcid}\"" if vpcid
          # comline = comline + " \"Name=tag:externalid,Values=#{externalid}\"" if externalid
          # instances=@shellout.cli(comline, verbose)
          # textout.puts(instances) if textout
          # return instances
          filters= {}
          filters['vpc-id']=vpcid if vpcid
          filters['tag:externalid']=externalid if externalid
          view=viewtype=='yaml'? 'json':viewtype
          @aws.awscli.home=home
          @aws.awscli.command_ec2.describeInstances.execute(region,view ,filters, textout, verbose,profile)
          instances = @aws.awscli.data_ec2.instance.view(viewtype)
          textout.puts(instances) if textout
          return instances
        end

        def view_images(region, viewtype, owner, imageid, textout=nil, verbose=nil)
          comline="aws --output #{viewtype} --region #{region} ec2 describe-images"
          comline = "#{comline} --owner #{owner}" if owner
          comline = "#{comline} --image-ids #{imageid}" if imageid
          images=@shellout.cli(comline, verbose)
          textout.puts(images) if textout
          return images
        end

        def exists(region, textout=nil, verbose=nil, vpcid, externalid)
          instances=JSON.parse(view(region, 'json', nil, verbose, vpcid, externalid))
          val = (instances["Reservations"].count == 1) && (instances["Reservations"][0]["Instances"].count == 1)
          instance_id = val ? instances["Reservations"][0]["Instances"][0]["InstanceId"] : nil
          sgroups = val ? instances["Reservations"][0]["Instances"][0]["SecurityGroups"] : nil
          textout.puts val.to_s if textout
          return val, instance_id, sgroups
        end

        def instance_id_by_external_id(region, externalid, vpcid=nil, textout=nil, verbose=nil)
          val, instance_id, sgroups=exists(region, nil, verbose, vpcid, externalid)
          return instance_id
        end

        def network_interface_json(region, verbose, vpcid, ip, groupname)
          ec2_dir = File.dirname(__FILE__)
          ip_to_subnet_id = @aws.ec2.subnet.id_by_ip(region, verbose, vpcid, ip)
          subnet_id=ip_to_subnet_id
          security_group_id= @aws.ec2.security_group.id_by_name(region, nil, verbose, vpcid, groupname)
          new_hash= [{"Groups" => [security_group_id], "PrivateIpAddress" => "#{ip}", "DeviceIndex" => 0, "SubnetId" => ip_to_subnet_id}]
          return new_hash.to_json
        end

        def block_device_mapping(region, owner, verbose, root_size, image_id)
          image_descriptions=JSON.parse(view_images(region, 'json', owner, image_id, nil, verbose))
          image_mappings=image_descriptions['Images'][0]["BlockDeviceMappings"]
          image_root=image_descriptions['Images'][0]["RootDeviceName"]
          image_mappings.each do |x|
            if x["DeviceName"]==image_root
              if x["Ebs"]["VolumeSize"].to_i > root_size.to_i
                raise "The image root size is greater than the specified root size. image=#{x["Ebs"]["VolumeSize"]} > rootsize=#{root_size}"
                exit 1
              end
              x["Ebs"]["VolumeSize"]=root_size.to_i
              #You cannot specify the encrypted flag if specifying a snapshot id in a block device mapping. -AWS
              x["Ebs"].delete("Encrypted") if x["Ebs"]["SnapshotId"]
            end
          end
          return image_mappings.to_json
        end

        def random_clienttoken
          (0...8).map { (65 + rand(26)).chr }.join
        end

        def placement_aggregate(zone, tenancy)
          aggregate_value=[]
          aggregate_value << "AvailabilityZone=#{zone}" if zone
          aggregate_value << "Tenancy=#{tenancy}" if tenancy
          aggregate_value.join(",")
        end

        def declare(externalid, image, owner, nodetype, root, zone, key, sgroup, privateip, optimized, apiterminate, clienttoken, region, textout, verbose, vpcid, nagios, ufile, no_sdcheck, skip_running_check, volsize, volume, tenancy, profilename, userdata)
          if ufile
            @undofile.prepend("zaws compute delete #{externalid} --region #{region} --vpcid #{vpcid} $XTRA_OPTS", '#Delete instance', ufile)
          end
          compute_exists, instance_id, sgroups = exists(region, nil, verbose, vpcid, externalid)
          return ZAWS::Helper::Output.binary_nagios_check(compute_exists, "OK: Instance already exists.", "CRITICAL: Instance does not exist.", textout) if nagios
          if not compute_exists
            clienttoken=random_clienttoken if not clienttoken
            comline = "aws --region #{region} ec2 run-instances --image-id #{image} --key-name #{key} --instance-type #{nodetype}"
            #comline = comline + " --user-data 'file://#{options[:userdata]}'" if options[:userdata]
            comline = comline + " --placement #{placement_aggregate(zone, tenancy)}" if zone or tenancy
            comline = comline + " --block-device-mappings \"#{block_device_mapping(region, owner, verbose, root, image).gsub("\"","\\\"")}\"" if root
            comline = apiterminate ? comline + " --enable-api-termination" : comline + " --disable-api-termination"
            comline = comline + " --client-token #{clienttoken}"
            comline = comline + " --network-interfaces \"#{network_interface_json(region, verbose, vpcid, privateip[0], sgroup).gsub("\"","\\\"")}\"" if privateip # Difference between vpc and classic
            #comline = comline + " --security-groups '#{options[:securitygroup]}'" if not options[:privateip]
            comline = comline + " --iam-instance-profile Name=\"#{profilename}\"" if profilename
            comline = comline + " --user-data \"file://#{userdata}\"" if userdata

            comline = optimized ? comline + " --ebs-optimized" : comline + " --no-ebs-optimized"
            newinstance=JSON.parse(@shellout.cli(comline, verbose))
            ZAWS::Helper::Output.out_change(textout, "Instance created.") if (newinstance["Instances"] and newinstance["Instances"][0]["InstanceId"])
            new_instanceid=newinstance["Instances"][0]["InstanceId"]
            tag_resource(region, new_instanceid, externalid, verbose)
            instance_running?(region, vpcid, externalid, 60, 5, verbose) if not skip_running_check
            add_volume(region, new_instanceid, externalid, privateip, volume, zone, volsize, verbose) if volume
            nosdcheck(region, new_instanceid, verbose) if no_sdcheck # Needed for NAT instances.
          else
            ZAWS::Helper::Output.out_no_op(textout, "Instance already exists. Creation skipped.")
          end

        end

        def delete(region, textout=nil, verbose=nil, vpcid, externalid)
          compute_exists, instance_id, sgroups = exists(region, nil, verbose, vpcid, externalid)
          if compute_exists
            comline = "aws --region #{region} ec2 terminate-instances --instance-ids #{instance_id}"
            delinstance=JSON.parse(@shellout.cli(comline, verbose))
            ZAWS::Helper::Output.out_change(textout, "Instance deleted.") if delinstance["TerimatingInstances"]
          else
            ZAWS::Helper::Output.out_no_op(textout, "Instance does not exist. Skipping deletion.")
          end
        end

        def exists_security_group_assoc(region, textout, verbose, vpcid, externalid, sgroup)
          compute_exists, instance_id, sgroups = exists(region, nil, verbose, vpcid, externalid)
          sgroup_exists, sgroupid = @aws.ec2.security_group.exists(region, verbose, vpcid, sgroup)
          verbose.puts "compute_exists=#{compute_exists}" if verbose
          verbose.puts "sgroup_exists=#{sgroup_exists}" if verbose
          verbose.puts "sgroups=#{sgroups}" if verbose
          if compute_exists and sgroup_exists
            assoc_exists = sgroups.any? { |z| z["GroupId"] == "#{sgroupid}" }
            textout.puts assoc_exists.to_s if textout
            return assoc_exists, instance_id, sgroupid
          else
            textout.puts false if textout
            return false, instance_id, sgroupid
          end
        end

        def assoc_security_group(region, textout, verbose, vpcid, externalid, sgroup)
          assoc_exists, instance_id, sgroupid=exists_security_group_assoc(region, nil, verbose, vpcid, externalid, sgroup)
          if not assoc_exists
            comline = "aws --region #{region} ec2 modify-instance-attribute --instance-id #{instance_id} --groups #{sgroupid}"
            verbose.puts "comline=#{comline}" if verbose
            assocsgroup=JSON.parse(@shellout.cli(comline, verbose))
            ZAWS::Helper::Output.out_change(textout, "Security Group Association Changed.") if assocsgroup["return"]=="true"
          else
            ZAWS::Helper::Output.out_no_op(textout, "Security Group Association Not Changed.")
          end
        end

        def tag_resource(region, resourceid, externalid, verbose=nil)
          comline="aws --output json --region #{region} ec2 create-tags --resources #{resourceid} --tags \"Key=externalid,Value=#{externalid}\""
          tag_creation=@shellout.cli(comline, verbose)
          comline="aws --output json --region #{region} ec2 create-tags --resources #{resourceid} --tags \"Key=Name,Value=#{externalid}\""
          tag_creation=@shellout.cli(comline, verbose)
        end

        def nosdcheck(region, instanceid, verbose=nil)
          comline = "aws --output json --region #{region} ec2 modify-instance-attribute --instance-id #{instanceid} --no-source-dest-check"
          nosdcheck_result=JSON.parse(@shellout.cli(comline, verbose))
        end

        def instance_ping?(ip, statetimeout, sleeptime, verbose=nil)
          begin
            Timeout.timeout(statetimeout) do
              begin
                comline ="ping -q -c 2 #{ip}"
                @shellout.cli(comline, verbose)
              rescue Mixlib::ShellOut::ShellCommandFailed
                sleep(sleeptime)
                retry
              end
            end
          rescue Timeout::Error
            raise StandardError.new('Timeout before instance responded to ping.')
          end
          return true
        end

        def instance_running?(region, vpcid, externalid, statetimeout, sleeptime, verbose=nil)
          begin
            Timeout.timeout(statetimeout) do
              begin
                sleep(sleeptime)
                query_instance=JSON.parse(view(region, 'json', nil, verbose, vpcid, externalid))
              end while query_instance["Reservations"][0]["Instances"][0]["State"]["Code"]!=16
            end
          rescue Timeout::Error
            raise StandardError.new('Timeout before instance state code set to running(16).')
          end
        end

        def add_volume(region, instanceid, externalid, ip, volume, zone, volsize, verbose=nil)
          comline = "aws --output json --region #{region} ec2 create-volume --availability-zone #{zone} --size #{volsize}"
          new_volume=JSON.parse(@shellout.cli(comline, verbose))
          new_volumeid=new_volume["VolumeId"]
          tag_resource(region, new_volumeid, externalid, verbose)
          if instance_ping?(ip, 10, 1)
            comline = "aws --output json ec2 attach-volume --region #{region} --volume-id #{new_volumeid} --instance-id #{instanceid} --device #{volume}"
            volattach=JSON.parse(@shellout.cli(comline, verbose))
          end
        end

        def exists_secondary_ip(region, ip, textout, verbose, vpcid, externalid)
          compute_exists, instance_id, sgroups = exists(region, nil, verbose, vpcid, externalid)
          if compute_exists
            query_instance=JSON.parse(view(region, 'json', nil, verbose, vpcid, externalid))
            val = query_instance["Reservations"][0]["Instances"][0]["NetworkInterfaces"][0]["PrivateIpAddresses"].any? { |x| x["PrivateIpAddress"] == "#{ip}" }
            netid = query_instance["Reservations"][0]["Instances"][0]["NetworkInterfaces"][0]["NetworkInterfaceId"]
            textout.puts val.to_s if textout
            return val, true, netid
          else
            return false, false, nil
          end
        end

        def declare_secondary_ip(region, ip, textout, verbose, vpcid, externalid, nagios, ufile)
          if ufile
            @undofile.prepend("zaws compute delete_secondary_ip #{externalid} #{ip} --region #{region} --vpcid #{vpcid} $XTRA_OPTS", '#Delete secondary ip', ufile)
          end
          compute_exists, instance_id, sgroups = exists(region, nil, verbose, vpcid, externalid)
          secondary_ip_exists, compute_exists, network_interface = exists_secondary_ip(region, ip, nil, verbose, vpcid, externalid)
          return ZAWS::Helper::Output.binary_nagios_check(secondary_ip_exists, "OK: Secondary ip exists.", "CRITICAL: Secondary ip does not exist.", textout) if nagios
          if not secondary_ip_exists and compute_exists
            comline = "aws --output json --region #{region} ec2 assign-private-ip-addresses --network-interface-id \"#{network_interface}\" --private-ip-addresses \"#{ip}\""
            assignreturn = JSON.parse(@shellout.cli(comline, verbose))
            ZAWS::Helper::Output.out_change(textout, "Secondary ip assigned.") if assignreturn["return"] == "true"
          else
            ZAWS::Helper::Output.out_no_op(textout, "Secondary ip already exists. Skipping assignment.")
          end
        end

        def delete_secondary_ip(region, ip, textout, verbose, vpcid, externalid)
          secondary_ip_exists, compute_exists, network_interface = exists_secondary_ip(region, ip, nil, verbose, vpcid, externalid)
          if secondary_ip_exists and compute_exists
            comline = "aws --output json --region #{region} ec2 unassign-private-ip-addresses --network-interface-id \"#{network_interface}\" --private-ip-addresses \"#{ip}\""
            assignreturn = JSON.parse(@shellout.cli(comline, verbose))
            ZAWS::Helper::Output.out_change(textout, "Secondary ip deleted.") if assignreturn["return"] == "true"
          else
            ZAWS::Helper::Output.out_no_op(textout, "Secondary IP does not exists, skipping deletion.")
          end
        end

        def interval_eligible(policy_arn=nil, region, textout, verbose)
          @aws.awscli.command_iam.getPolicy.execute(policy_arn, 'json', verbose)
          version=@aws.awscli.data_iam.policy.defaultVersion
          @aws.awscli.command_iam.getPolicyVersion.execute(policy_arn, version, 'json', verbose)
          instanceids = @aws.awscli.data_iam.policy_document.resource_instance_ids()
          @aws.awscli.command_ec2.describeInstances.execute(region, 'json', {}, textout, verbose)
          instancenames = @aws.awscli.data_ec2.instance.names_by_ids(instanceids)
          textout.puts(instancenames) if textout
        end

        def set_interval(policy_arn=nil, name=nil, externalid=nil, hours, email, region, textout, verbose, overridebasetime)
          @aws.awscli.command_iam.getPolicy.execute(policy_arn, 'json', verbose)
          version=@aws.awscli.data_iam.policy.defaultVersion
          @aws.awscli.command_iam.getPolicyVersion.execute(policy_arn, version, 'json', verbose)
          allowed_instanceids = @aws.awscli.data_iam.policy_document.resource_instance_ids()
          @aws.awscli.command_ec2.describeInstances.execute(region, 'json', {}, textout, verbose)
          target_instanceid = @aws.awscli.data_ec2.instance.instanceid(name, externalid)
          if allowed_instanceids =~ /#{target_instanceid}/
            now_time = overridebasetime ? overridebasetime.to_i : Time.now.to_i
            interval_time = now_time + (hours.to_i*60*60)
            tag_value="#{now_time}:#{interval_time}:#{email}"
            @aws.awscli.command_ec2.createTags.execute(target_instanceid, region, 'interval', tag_value, textout, verbose)
            textout.puts("Instance #{name ? name : externalid} tagged: Key=interval,Value=#{tag_value}") if textout
          else
            textout.puts("Target instance is not in the allowed list accoring to the specified policy.")
          end
        end

        def interval_cron(policy_arn=nil, region, textout, verbose, overridebasetime)
          @aws.awscli.command_iam.getPolicy.execute(policy_arn, 'json', verbose)
          version=@aws.awscli.data_iam.policy.defaultVersion
          @aws.awscli.command_iam.getPolicyVersion.execute(policy_arn, version, 'json', verbose)
          allowed_instanceids = @aws.awscli.data_iam.policy_document.resource_instance_ids()
          @aws.awscli.command_ec2.describeInstances.execute(region, 'json', {}, textout, verbose)
          allowed_instanceids.split("\n").each do |id|
            instance_name = @aws.awscli.data_ec2.instance.name(id)
            instance_externalid = @aws.awscli.data_ec2.instance.name(id)
            instance_status = @aws.awscli.data_ec2.instance.status(instance_name, instance_externalid)
            if @aws.awscli.data_ec2.instance.has_interval?(id)
              interval_start = @aws.awscli.data_ec2.instance.interval_start(id)
              interval_end = @aws.awscli.data_ec2.instance.interval_end(id)
              interval_email = @aws.awscli.data_ec2.instance.interval_email(id)
              now_time = overridebasetime ? overridebasetime.to_i : Time.now.to_i
              verbose.puts "DEBUG: instance_name=#{instance_name},instance_externalid=#{instance_externalid}" if verbose
              verbose.puts "DEBUG: instance_status=#{instance_status},interval_email=#{interval_email}" if verbose
              verbose.puts "DEBUG: interval_start=#{interval_start},interval_end=#{interval_end}" if verbose
              if now_time > interval_end.to_i and instance_status == "running"
                @aws.awscli.command_ec2.stopInstances.execute(id, region, textout, verbose)
                textout.puts("Instance #{instance_name} stopped.") if textout and instance_name
              end
              if now_time < interval_end.to_i and instance_status == "stopped"
                @aws.awscli.command_ec2.runInstances.execute(id, region, textout, verbose)
                textout.puts("Instance #{instance_name} started.") if textout and instance_name
              end
            else
              textout.puts("Instance #{instance_name} does not have an interval set.")
            end
          end
        end

        def start(name=nil, externalid=nil, region, textout, verbose, skip_running_check)
          @aws.awscli.command_ec2.describeInstances.execute(region, 'json', {}, textout, verbose)
          instance_status = @aws.awscli.data_ec2.instance.status(name, externalid)
          instance_id = @aws.awscli.data_ec2.instance.instanceid(name, externalid)
          externalid = @aws.awscli.data_ec2.instance.externalid(instance_id)
          case instance_status
            when "stopped"
              @aws.awscli.command_ec2.runInstances.execute(instance_id, region, textout, verbose)
              instance_running?(region, nil, externalid, 60, 5, verbose) if not skip_running_check
              textout.puts("Instance #{name} started.") if textout and name
          end
        end

        def stop(name=nil, externalid=nil, region, textout, verbose, skip_running_check)
          @aws.awscli.command_ec2.describeInstances.execute(region, 'json', {}, textout, verbose)
          instance_status = @aws.awscli.data_ec2.instance.status(name, externalid)
          instance_id = @aws.awscli.data_ec2.instance.instanceid(name, externalid)
          externalid = @aws.awscli.data_ec2.instance.externalid(instance_id)
          case instance_status
            when "running"
              @aws.awscli.command_ec2.stopInstances.execute(instance_id, region, textout, verbose)
              textout.puts("Instance #{name} stopped.") if textout and name
          end
        end

      end
    end
  end
end
