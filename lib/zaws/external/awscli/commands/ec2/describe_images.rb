module ZAWS
  class External
    class AWSCLI
      class Commands
        class EC2
          class DescribeImages

            def initialize(shellout=nil, awscli=nil)
              #super(shellout, awscli)
              @shellout=shellout
              @awscli=awscli
              clear_settings
            end

            def aws
              @aws ||= ZAWS::External::AWSCLI::Commands::AWS.new(self)
              @aws
            end

            def filter
              @filter ||= ZAWS::External::AWSCLI::Commands::EC2::Filter.new()
              @filter
            end

            def clear_settings
              @aws=nil
              @filter=nil
              @owner=nil
              @image_ids=nil
              self
            end

            def owner(owner)
              @owner=owner
              self
            end

            def image_ids(id)
              @image_ids=id
              self
            end

            def get_command
              command = "ec2 describe-images"
              command = "#{command} --owner #{@owner}" if @owner
              command = "#{command} --image-ids #{@image_ids}" if @image_ids
              command = "#{command} #{@filter.get_command}" if @filter
              return command
            end


          end
        end
      end
    end
  end
end

