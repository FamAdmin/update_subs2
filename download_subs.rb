#download_subs.rb
require 'dotenv'
Dotenv.load
require 'httparty'
require 'resque'
#require 'sinatra'
require 'active_record'
require "sinatra/activerecord"
require_relative 'models/model'


module DownloadSubs
    class GetSubs

        def initialize
            recharge_regular = ENV['RECHARGE_ACCESS_TOKEN']
            @my_header = {
                "X-Recharge-Access-Token" => recharge_regular
              }
            @my_change_header = {
                "X-Recharge-Access-Token" => recharge_regular,
                "Accept" => "application/json",
                "Content-Type" =>"application/json"
              }

        end


        def get_all_active_subs
            puts "Getting all active subs"
            Subscription.delete_all
            # Now reset index
            ActiveRecord::Base.connection.reset_pk_sequence!('subscriptions')
            SubCollectionSizes.delete_all
            ActiveRecord::Base.connection.reset_pk_sequence!('sub_collection_sizes')

            subscriptions = HTTParty.get("https://api.rechargeapps.com/subscriptions/count?status=ACTIVE", :timeout => 80, :headers => @my_header)
            #my_response = JSON.parse(subscriptions)
            my_response = subscriptions
            my_count = my_response['count'].to_i

            start = Time.now    
            page_size = 250
            num_pages = (my_count/page_size.to_f).ceil

            puts "We have #{my_count} subscriptions and #{(my_count/page_size.to_f).ceil} pages to download"
            #puts "Sleeping 3 secs"
            #sleep 3

            sub_array = Array.new
            sub_collection_sizes_array = Array.new

            1.upto(num_pages) do |page|
                mysubs = HTTParty.get("https://api.rechargeapps.com/subscriptions?status=ACTIVE&limit=250&page=#{page}", :timeout => 120, :headers => @my_header)
                #puts mysubs.inspect
                recharge_limit = mysubs.response["x-recharge-limit"]
                puts "Here recharge_limit = #{recharge_limit}"

                local_sub = mysubs['subscriptions']
                local_sub.each do |sub|
                    puts "-------------------"
                    puts sub['id']
                    puts sub.inspect
                    puts "------------------"
                

                    subscription_id = sub['id']

                    address_id = sub['address_id']
                    customer_id = sub['customer_id']
                    created_at = sub['created_at']
                    updated_at = sub['updated_at']
                    next_charge_scheduled_at = sub['next_charge_scheduled_at']
                    cancelled_at = sub['cancelled_at']
                    product_title = sub['product_title']
                    price = sub['price']
                    quantity = sub['quantity']
                    status = sub['status']
                    shopify_product_id = sub['shopify_product_id']
                    shopify_variant_id = sub['shopify_variant_id']
                    sku = sub['sku']
                    order_interval_unit = sub['order_interval_unit']
                    order_interval_frequency = sub['order_interval_frequency']
                    charge_interval_frequency = sub['charge_interval_frequency']
                    order_day_of_month = sub['order_day_of_month']
                    order_day_of_week = sub['order_day_of_week']
                    raw_properties = sub['properties']
                    properties = sub['properties'].to_json
                    expire_after = sub['expire_after_specific_number_charges']
                    is_prepaid = sub['is_prepaid']
                    email = sub['email']
                    #create sub
                    #Subscription.create(subscription_id: subscription_id, address_id: address_id, customer_id: customer_id, created_at: created_at, updated_at: updated_at, next_charge_scheduled_at: next_charge_scheduled_at, cancelled_at: cancelled_at, product_title: product_title, price: price, quantity: quantity, status: status, shopify_product_id: shopify_product_id, shopify_variant_id: shopify_variant_id, sku: sku, order_interval_unit: order_interval_unit, order_interval_frequency: order_interval_frequency, charge_interval_frequency: charge_interval_frequency, order_day_of_month: order_day_of_month, order_day_of_week: order_day_of_week, raw_line_item_properties: properties, expire_after_specific_number_charges: expire_after, is_prepaid: is_prepaid, email: email)
                    sub_array << { "subscription_id" => subscription_id, "address_id" => address_id, "customer_id" => customer_id, "created_at" => created_at, "updated_at" => updated_at, "next_charge_scheduled_at" => next_charge_scheduled_at, "cancelled_at" => cancelled_at, "product_title" => product_title, "price" => price, "quantity" =>  quantity, "status" => status, "shopify_product_id" => shopify_product_id, "shopify_variant_id" => shopify_variant_id, "sku" => sku, "order_interval_unit" => order_interval_unit, "order_interval_frequency" => order_interval_frequency, "charge_interval_frequency" => charge_interval_frequency, "order_day_of_month" => order_day_of_month, "order_day_of_week" => order_day_of_week, "raw_line_item_properties" => properties, "expire_after_specific_number_charges" => expire_after, "is_prepaid" => is_prepaid, "email" => email}


                    
                    



                    #create sub_collection_sizes

                    my_data = create_properties(raw_properties)

                    product_collection = my_data['product_collection']
                    leggings = my_data['leggings']
                    tops = my_data['tops']
                    sports_bra = my_data['sports_bra']
                    sports_jacket = my_data['sports_jacket']
                    gloves = my_data['gloves']

                    sub_collection_sizes_array << {"subscription_id" => subscription_id, "product_collection" => product_collection, "leggings" => leggings, "sports_bra" => sports_bra, "tops" => tops, "sports_jacket" => sports_jacket, "gloves" => gloves, "prepaid" => is_prepaid, "next_charge_scheduled_at" => next_charge_scheduled_at, "created_at" => created_at, "updated_at" => updated_at}

                    #SubCollectionSizes.create(subscription_id: subscription_id,
                    #    product_collection: product_collection,
                    #    leggings: leggings, tops: tops,
                    #    sports_bra: sports_bra,
                    #    sports_jacket: sports_jacket,
                    #    gloves: gloves, prepaid: is_prepaid, next_charge_scheduled_at: next_charge_scheduled_at)
                end



            puts "Done with page #{page} of #{num_pages} pages"
            determine_limits(recharge_limit, 0.65)
            current = Time.now
            duration = (current - start).ceil
            puts "Been running #{duration} seconds"
            end
            sub_array.uniq!
            sub_collection_sizes_array.uniq!
            result = Subscription.upsert_all(sub_array, unique_by: :subscription_id)
            puts result.inspect
            result2 = SubCollectionSizes.upsert_all(sub_collection_sizes_array)
            puts result2.inspect
            puts "All done with subs"

            

        end

        def get_all_orders
            puts "Getting all orders"
            Order.delete_all
            OrderLineItemsFixed.delete_all
            OrderCollectionSize.delete_all
            ActiveRecord::Base.connection.reset_pk_sequence!('orders')
            ActiveRecord::Base.connection.reset_pk_sequence!('order_line_items_fixed')
            ActiveRecord::Base.connection.reset_pk_sequence!('order_collection_sizes')
            min_max = get_min_max
            min = min_max['min']
            max = min_max['max']

            orders_count = HTTParty.get("https://api.rechargeapps.com/orders/count?scheduled_at_min=\'#{min}\'&scheduled_at_max=\'#{max}\'", :headers => my_header)
            #my_response = JSON.parse(subscriptions)
            my_response = orders_count
            my_count = my_response['count'].to_i
            puts "We have #{my_count} orders for this month"


        end


        def create_properties(raw_properties)
            product_collection = raw_properties.select{|x| x['name'] == 'product_collection'}
            if product_collection != []
                if product_collection.first['value'] != [] && !product_collection.first['value'].nil?
                product_collection = product_collection.first['value']
                else
                    product_collection = nil
                end
            else
                product_collection = nil
            end
            leggings = raw_properties.select{|x| x['name'] == 'leggings'}
            if leggings != []
                if leggings.first['value'] != [] && !leggings.first['value'].nil?
                leggings = leggings.first['value'].upcase
                else
                leggings = nil?
                end
            else
                leggings = nil
            end
            tops = raw_properties.select{|x| x['name'] == 'tops'}
            if tops != []
                if tops.first['value'] != [] && !tops.first['value'].nil?
                tops = tops.first['value'].upcase
                else
                tops = nil?
                end
            else
                tops = nil
            end
            sports_bra = raw_properties.select{|x| x['name'] == 'sports-bra'}
            if sports_bra != []
                if sports_bra.first['value'] != [] && !sports_bra.first['value'].nil?
                sports_bra = sports_bra.first['value'].upcase
                else
                sports_bra = nil
                end
            else
                sports_bra = nil
            end
            sports_jacket = raw_properties.select{|x| x['name'] == 'sports-jacket'}
    
            if sports_jacket != []
                if sports_jacket.first['value'] != [] && !sports_jacket.first['value'].nil?
                sports_jacket = sports_jacket.first['value'].upcase
                else
                sports_jacket = nil
                end
            else
                sports_jacket = nil
            end
            gloves = raw_properties.select{|x| x['name'] == 'gloves'}
            if gloves != []
                if gloves.first['value'] != [] && !gloves.first['value'].nil?
                gloves = gloves.first['value'].upcase
                else
                gloves = nil
                end
            else
                gloves = nil
            end
            #puts charge_interval_frequency.inspect
            
            stuff_to_return = {"product_collection" => product_collection, "leggings" => leggings, "tops" => tops, "sports_bra" => sports_bra, "sports_jacket" => sports_jacket, "gloves" => gloves}
            return stuff_to_return
    
        end

        def get_min_max
            my_yesterday = Date.today - 3
            my_yesterday_str = my_yesterday.strftime("%Y-%m-%d")
            my_four_months = Date.today >> 2
            my_four_months = my_four_months.end_of_month
            my_four_months_str = my_four_months.strftime("%Y-%m-%d")
            my_hash = Hash.new
            my_hash = {"min" => my_yesterday_str, "max" => my_four_months_str}
            return my_hash

        end

        def determine_limits(recharge_header, limit)
            puts "recharge_header = #{recharge_header}"
            puts "sleeping 1 second"
            sleep 1
            my_numbers = recharge_header.split("/")
            my_numerator = my_numbers[0].to_f
            my_denominator = my_numbers[1].to_f
            my_limits = (my_numerator/ my_denominator)
            puts "We are using #{my_limits} % of our API calls"
            if my_limits > limit
                puts "Sleeping 10 seconds"
                sleep 10
            else
                puts "not sleeping at all"
            end

        end

        


    end
end