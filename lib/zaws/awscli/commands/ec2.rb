module ZAWS
  class AWSCLI
	class Commands
	  class EC2
		def initialize(shellout,aws)
		  @shellout=shellout
		  @aws=aws
		end

		def CreateSubnet 
		  @_createSubnet ||= (ZAWS::AWSCLI::Commands::EC2::CreateSubnet.new(@shellout,@aws))
		  return @_createSubnet
		end

		def DescribeSubnet 
		  @_describeSubnet ||= (ZAWS::AWSCLI::Commands::EC2::DescribeSubnet.new(@shellout,@aws))
		  return @_describeSubnet
		end

		def describeInstances 
		  @_describeInstances ||= (ZAWS::AWSCLI::Commands::EC2::DescribeInstances.new(@shellout,@aws))
		  return @_describeInstances
		end


	  end
	end
  end
end
