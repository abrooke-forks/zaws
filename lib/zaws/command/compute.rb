require 'thor'

module ZAWS
  module Command
    class Compute < Thor
      class_option :region, :type => :string, :desc => "AWS Region", :banner => "<region>", :aliases => :r, :required => true
      class_option :verbose, :type => :boolean, :desc => "Verbose outout", :aliases => :d, :default => false

      attr_accessor :aws
      attr_accessor :out
      attr_accessor :print_exit_code

      def initialize(*args)
        super
        shellout=ZAWS::Helper::Shell.new
        awscli = ZAWS::AWSCLI.new(shellout,false)
        @aws = ZAWS::AWS.new(shellout, awscli)
        @out = $stdout
        @print_exit_code = false
      end

      desc "view", "View compute instances."
      option :viewtype, :type => :string, :desc => "View type, json or table", :banner => "<viewtype>", :aliases => :w, :default => "table"
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil
      option :profile, :type => :string, :desc => "AWS Profile", :banner => "<profile>", :aliases => :p, :default => nil
      option :home, :type => :string, :default => ENV['HOME'], :desc => 'Home directory location for credentials file'
      def view
        region =options[:region]
        viewtype=options[:viewtype]
        verbose=(options[:verbose] ? @out : nil)
        vpcid=options[:vpcid]
        profile=options[:profile]
        home=options[:home]
        @aws.ec2.compute.view(region, viewtype, @out, verbose, vpcid,nil, profile,home)
      end

      desc "view_images", "View images, by default the images are owned by self (your account))."
      option :viewtype, :type => :string, :desc => "View type, json or table", :banner => "<viewtype>", :aliases => :w, :default => "table"
      option :owner, :type => :string, :desc => "filter by owner of the images", :banner => "<owner>", :aliases => :o, :default => "self"
      option :imageid, :type => :string, :desc => "filter by owner of the images", :banner => "<imageid>", :aliases => :i, :default => nil

      def view_images
        @aws.ec2.compute.view_images(options[:region], options[:viewtype], options[:owner], options[:imageid], @out, (options[:verbose] ? @out : nil))
      end

      desc "exists_by_external_id EXTERNAL_ID", "Determine if an instance exists by the instance's EXTERNAL_ID."
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil

      def exists_by_external_id(externalid)
        val, instance_id, sgroups=@aws.ec2.compute.exists(options[:region], @out, (options[:verbose] ? @out : nil), options[:vpcid], externalid)
        return val
      end

      desc "declare EXTERNAL_ID IMAGE OWNER TYPE ROOT_SIZE ZONE KEY SECURITY_GROUP", "Declare a compute instance."
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil
      option :privateip, :type => :array, :desc => "array of private ip addresses, in vpc, each given a network interface", :banner => "<privateip>", :aliases => :p, :default => nil
      option :optimized, :type => :string, :desc => "ebs optimized", :banner => "<optimized>", :aliases => :i, :default => false
      option :apiterminate, :type => :string, :desc => "ebs optimized", :banner => "<apiterminate>", :aliases => :a, :default => false
      option :clienttoken, :type => :string, :desc => "AWS VPC id", :banner => "<clienttoken>", :aliases => :c, :default => nil
      option :check, :type => :boolean, :desc => "Returns a check result", :aliases => :n, :default => false
      option :undofile, :type => :string, :desc => "File for undo commands", :banner => "<undofile>", :aliases => :f, :default => nil
      option :nosdcheck, :type => :boolean, :desc => "No source dest check (primarily needed for NAT instances)", :banner => "<nosdcheck>", :aliases => :s, :default => false
      option :skipruncheck, :type => :boolean, :desc => "Flag to skip the running check during testing.", :banner => "<skipruncheck>", :aliases => :r, :default => false
      option :volume, :type => :string, :desc => "volume (ex: --volume /dev/sdf)", :banner => "<volume>"
      option :volsize, :type => :string, :desc => "volsize", :banner => "<volsize>"
      option :tenancy, :type => :string, :desc => "tenancy can be defualt|dedicated", :banner => "<tenancy>" #AWS defaults to "default" when not specified
      option :profilename, :type => :string, :desc => "instance profile name", :banner => "<profilename>"
      option :userdata, :type => :string, :desc => "instance userdata yml filename", :banner => "<userdata>"
      def declare(externalid, image, owner, type, root, zone, key, sgroup)
        val=@aws.ec2.compute.declare(externalid, image, owner, type, root, zone, key, sgroup, options[:privateip], options[:optimized], options[:apiterminate], options[:clienttoken], options[:region], @out, (options[:verbose] ? @out : nil), options[:vpcid], options[:check], options[:undofile], options[:nosdcheck], options[:skipruncheck], options[:volsize], options[:volume], options[:tenancy], options[:profilename], options[:userdata])
        return val
      end

      desc "delete EXTERNAL_ID", "Delete the instance's an instance by EXTERNAL_ID, this only works if api termination is enabled."
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil

      def delete(externalid)
        @aws.ec2.compute.delete(options[:region], @out, (options[:verbose] ? @out : nil), options[:vpcid], externalid)
      end

      desc "exists_security_group_assoc EXTERNAL_ID SECURITY_GROUP", "Determine if an instance with an EXTERNAL_ID is associated to a named SECURITY_GROUP."
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil

      def exists_security_group_assoc(externalid, security_group)
        val, instancid, sgroupid=@aws.ec2.compute.exists_security_group_assoc(options[:region], @out, (options[:verbose] ? @out : nil), options[:vpcid], externalid, security_group)
      end

      desc "assoc_security_group EXTERNAL_ID SECURITY_GROUP", "Associate a named SECURITY_GROUP to an instance by the instance's EXTERNAL_ID."
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil

      def assoc_security_group(externalid, security_group)
        @aws.ec2.compute.assoc_security_group(options[:region], @out, (options[:verbose] ? @out : nil), options[:vpcid], externalid, security_group)
      end

      desc "exists_secondary_ip EXTERNAL_ID IP", "Determine if a secondary IP exists by the instance's EXTERNAL_ID."
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil

      def exists_secondary_ip(externalid, ip)
        val, compute_exists, netid=@aws.ec2.compute.exists_secondary_ip(options[:region], ip, @out, (options[:verbose] ? @out : nil), options[:vpcid], externalid)
      end

      desc "declare_secondary_ip EXTERNAL_ID IP", "Declare secondary IP for instance by the instance's EXTERNAL_ID."
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil
      option :check, :type => :boolean, :desc => "Returns a check result", :aliases => :n, :default => false
      option :undofile, :type => :string, :desc => "File for undo commands", :banner => "<undofile>", :aliases => :f, :default => nil

      def declare_secondary_ip(externalid, ip)
        @aws.ec2.compute.declare_secondary_ip(options[:region], ip, @out, (options[:verbose] ? @out : nil), options[:vpcid], externalid, options[:check], options[:undofile])
      end

      desc "delete_secondary_ip EXTERNAL_ID IP", "Delete secondary IP for instance by the instance's EXTERNAL_ID."
      option :vpcid, :type => :string, :desc => "AWS VPC id", :banner => "<vpcid>", :aliases => :v, :default => nil

      def delete_secondary_ip(externalid, ip)
        @aws.ec2.compute.delete_secondary_ip(options[:region], ip, @out, (options[:verbose] ? @out : nil), options[:vpcid], externalid)
      end

      desc "interval_eligible", "present a list of instances by name eligible for start stop"
      option :policy_arn, :type => :string, :desc => "Policy Arn", :banner => "<policy>", :default => nil

      def interval_eligible
        @aws.ec2.compute.interval_eligible(options[:policy_arn], options[:region], @out, (options[:verbose] ? @out : nil))
      end

      desc "set_interval HOURS EMAIL", ""
      option :name, :type => :string, :desc => "Name", :banner => "<role>", :default => nil
      option :externalid, :type => :string, :desc => "Externalid", :banner => "<policy>", :default => nil
      option :overridebasetime, :type => :string, :desc => "Override basetime for testing, it will be used instead of now", :banner => "<overridebasetime>", :default => nil
      option :policy_arn, :type => :string, :desc => "Policy Arn", :banner => "<policy>", :default => nil

      def set_interval(hours, email)
        @aws.ec2.compute.set_interval(options[:policy_arn], options[:name], options[:externalid], hours, email, options[:region], @out, (options[:verbose] ? @out : nil), options[:overridebasetime])
      end

      desc "interval_cron POLICY_ARN", "This job will search through the hosts and stop and start hosts accourding to their interval tag setting"
      option :policy_arn, :type => :string, :desc => "Policy Arn", :banner => "<policy>", :default => nil
      option :overridebasetime, :type => :string, :desc => "Override basetime for testing, it will be used instead of now", :banner => "<overridebasetime>", :default => nil

      def interval_cron()
        @aws.ec2.compute.interval_cron(options[:policy_arn], options[:region], @out, (options[:verbose] ? @out : nil), options[:overridebasetime])
      end

      desc "start", "start instance specified"
      option :name, :type => :string, :desc => "Name", :banner => "<role>", :default => nil
      option :externalid, :type => :string, :desc => "Externalid", :banner => "<policy>", :default => nil
      option :skipruncheck, :type => :boolean, :desc => "Flag to skip the running check during testing.", :banner => "<skipruncheck>", :aliases => :r, :default => false

      def start()
        @aws.ec2.compute.start(options[:name], options[:externalid], options[:region], @out, (options[:verbose] ? @out : nil), options[:skipruncheck])
      end

      desc "stop", "stop instance specified"
      option :name, :type => :string, :desc => "Name", :banner => "<role>", :default => nil
      option :externalid, :type => :string, :desc => "Externalid", :banner => "<policy>", :default => nil
      option :skipruncheck, :type => :boolean, :desc => "Flag to skip the running check during testing.", :banner => "<skipruncheck>", :aliases => :r, :default => false

      def stop()
        @aws.ec2.compute.stop(options[:name], options[:externalid], options[:region], @out, (options[:verbose] ? @out : nil), options[:skipruncheck])
      end

    end
  end
end

	
