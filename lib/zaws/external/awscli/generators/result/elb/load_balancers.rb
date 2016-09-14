module ZAWS
  class External
    class AWSCLI
      class Generators
        class Result
          class ELB
            class LoadBalancers
              def initialize
                @load_balancers= {}
                @load_balancers["LoadBalancerDescriptions"]= []
                self
              end

              def name(load_balancer_number, name)
                resize_load_balancers_array(load_balancer_number)
                @load_balancers["LoadBalancerDescriptions"][load_balancer_number]["LoadBalancerName"]=name
                self
              end

              def resize_load_balancers_array(index)
                while index > @load_balancers["LoadBalancerDescriptions"].length-1
                  @load_balancers["LoadBalancerDescriptions"].push({})
                end
              end

              def add(load_balancers)
                @load_balancers["LoadBalancerDescriptions"].concat(load_balancers.get_load_balancers_array)
                self
              end

              def get_json
                @load_balancers.to_json
              end

              def get_load_balancers_array
                @load_balancers["LoadBalancerDescriptions"]
              end

            end
          end
        end
      end
    end
  end
end


