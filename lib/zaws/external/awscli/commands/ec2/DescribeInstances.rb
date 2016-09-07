module ZAWS
  class AWSCLI
    class Commands
      class EC2
        class DescribeInstances

          def initialize(shellout, awscli)
            @shellout=shellout
            @awscli=awscli
          end

          def execute(region, view, filters={}, textout=nil, verbose=nil,profile=nil)
            comline = "aws"
            comline = comline + " --output #{view}" 
            comline = comline + " --region #{region} ec2 describe-instances"
            comline = comline + " --profile #{profile}" if profile
            comline = comline + " --filter" if filters.length > 0
            filters.each do |key, item|
              comline = comline + " \"Name=#{key},Values=#{item}\""
            end
            unless @awscli.data_ec2.instance.load_cached(comline, verbose)
              @awscli.data_ec2.instance.load(comline, @shellout.cli(comline, verbose), verbose)
            end
          end

        end
      end
    end
  end
end