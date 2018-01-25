#update_subs.rb
require 'dotenv'
Dotenv.load
require 'httparty'
require 'resque'
require 'sinatra'
require 'active_record'
require "sinatra/activerecord"
require_relative 'models/model'
require_relative 'resque_helper'


module FixSubInfo
    class SubUpdater
    
    def initialize
      Dotenv.load
      recharge_regular = ENV['RECHARGE_ACCESS_TOKEN']
      @sleep_recharge = ENV['RECHARGE_SLEEP_TIME']
      @my_header = {
        "X-Recharge-Access-Token" => recharge_regular
      }
      @my_change_charge_header = {
        "X-Recharge-Access-Token" => recharge_regular,
        "Accept" => "application/json",
        "Content-Type" =>"application/json"
      }
      @uri = URI.parse(ENV['DATABASE_URL'])
      @conn = PG.connect(@uri.hostname, @uri.port, nil, nil, @uri.path[1..-1], @uri.user, @uri.password)

      
    end

    def get_current_products
        puts "Doing something"
        my_products = CurrentProduct.all
        my_products.each do |product|
            puts product.inspect
        end

    end

    def setup_subscription_update_table
        #sets up subscription update tables
        #first delete all records
        SubscriptionsUpdated.delete_all
        #Now reset index
        ActiveRecord::Base.connection.reset_pk_sequence!('subscriptions_updated')
        bad_prod_id1 = "69026938898"
        bad_prod_id2 = "69026316306"
        bad_prod_id3 = "52386037778"
        bad_prod_id4 = "78480408594"
        bad_prod_id5 = "78541520914"
        bad_prod_id6 = "78657093650"
        bad_prod_id7 = "91049066514"
        bad_prod_id8 = "91049230354"
        bad_prod_id9 = "91049197586"
        bad_prod_id10 = "91236171794"
        bad_prod_id11 = "126714937362"
        bad_prod_id12 = "91235975186"
        bad_prod_id13 = "126713757714"
        bad_prod_id14 = "91236466706"
        bad_prod_id15 = "126717034514"
        bad_prod_id15 = "91236368402"
        bad_prod_id16 = "126715920402"
        bad_prod_id17 = "109303332882"
        bad_prod_id18 = "126723686418"
        bad_prod_id19 = "109301366802"
        bad_prod_id20 = "126718771218"
        

        subs_update = "insert into subscriptions_updated (subscription_id, customer_id, updated_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id, raw_line_items) select subscription_id, customer_id, updated_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id, raw_line_item_properties from subscriptions where status = 'ACTIVE' and next_charge_scheduled_at > '2018-01-31' and (shopify_product_id = \'#{bad_prod_id1}\' or shopify_product_id = \'#{bad_prod_id2}\' or shopify_product_id = \'#{bad_prod_id3}\' or shopify_product_id = \'#{bad_prod_id4}\' or shopify_product_id = \'#{bad_prod_id5}\' or shopify_product_id = \'#{bad_prod_id6}\' or shopify_product_id = \'#{bad_prod_id7}\' or shopify_product_id = \'#{bad_prod_id8}\' or shopify_product_id = \'#{bad_prod_id9}\' or shopify_product_id = \'#{bad_prod_id10}\' or  shopify_product_id = \'#{bad_prod_id11}\' or shopify_product_id = \'#{bad_prod_id12}\'  or shopify_product_id = \'#{bad_prod_id13}\' or shopify_product_id = \'#{bad_prod_id14}\' or shopify_product_id = \'#{bad_prod_id15}\' or shopify_product_id = \'#{bad_prod_id16}\' or shopify_product_id = \'#{bad_prod_id17}\' or shopify_product_id = \'#{bad_prod_id18}\' or shopify_product_id = \'#{bad_prod_id19}\' or shopify_product_id = \'#{bad_prod_id20}\')"
        update_records = ActiveRecord::Base.connection.execute(subs_update)


    

    end

    def load_update_products
        UpdateProduct.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('update_products')
        #my_delete = "delete from update_products"
        #@conn.exec(my_delete)
        #my_reorder = "ALTER SEQUENCE current_products_id_seq RESTART WITH 1"
        #@conn.exec(my_reorder)
        my_insert = "insert into update_products (sku, product_title, shopify_product_id, shopify_variant_id, product_collection) values ($1, $2, $3, $4, $5)"
        @conn.prepare('statement1', "#{my_insert}")
        CSV.foreach('update_products.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
          #puts row.inspect
          sku = row['sku']
          product_title = row['product_title']
          shopify_product_id = row['shopify_product_id']
          shopify_variant_id = row['shopify_variant_id']
          product_collection = row['product_collection']
          
          @conn.exec_prepared('statement1', [sku, product_title, shopify_product_id, shopify_variant_id, product_collection])
        end
          @conn.close
  
      end

      def load_current_products

        CurrentProduct.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('current_products')

        #my_delete = "delete from current_products"
        #@conn.exec(my_delete)
        #my_reorder = "ALTER SEQUENCE current_products_id_seq RESTART WITH 1"
        #@conn.exec(my_reorder)
        my_insert = "insert into current_products (prod_id_key, prod_id_value, next_month_prod_id) values ($1, $2, $3)"
        @conn.prepare('statement1', "#{my_insert}")
        CSV.foreach('current_products.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
          #puts row.inspect
          prod_id_key = row['prod_id_key']
          prod_id_value = row['prod_id_value']
          next_month_prod_id = row['next_month_prod_id']
          
          @conn.exec_prepared('statement1', [prod_id_key, prod_id_value, next_month_prod_id])
        end
          @conn.close
  
      end

      def update_subscription_product
        params = {"action" => "updating subscription product info", "recharge_change_header" => @my_change_charge_header} 
        Resque.enqueue(UpdateSubscriptionProduct, params)
   
       end
   
       class UpdateSubscriptionProduct
         extend ResqueHelper
         
         @queue = "subscription_property_update"
         def self.perform(params)
           #logger.info "UpdateSubscriptionProduct#perform params: #{params.inspect}"
           update_subscriptions_next_month(params)
         end
   
       end

       def load_bad_alternate_monthly_box
        BadMonthlyBox.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('bad_monthly_box')
        CSV.foreach('ellie_threepack.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
          puts row.inspect
          subscription_id = row['subscription_id']
          bad_monthly = BadMonthlyBox.create(subscription_id: subscription_id)
          BadMonthlyBox.update_all(updated_at: nil)
          
        end


       end

       def update_bad_alternate_monthly_box
        params = {"action" => "bad_monthly_box", "recharge_change_header" => @my_change_charge_header} 
        Resque.enqueue(UpdateBadMonthlyBox, params)


       end

       class UpdateBadMonthlyBox
        extend ResqueHelper  
        @queue = "bad_monthly_box"
        def self.perform(params)
          #logger.info "UpdateSubscriptionProduct#perform params: #{params.inspect}"
          bad_monthly_box(params)
        end


       end



    end
end