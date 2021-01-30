require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  ruby '3.0.0'

  gem 'httparty'
  gem 'twilio-ruby'
  gem 'pry'
  gem 'actionview'
  gem 'dotenv'
end

require 'dotenv/load'
require 'pry'
require 'httparty'
require 'action_view'
require 'twilio-ruby'

# info
class Etherminer
  include HTTParty
  include ActionView::Helpers::NumberHelper

  attr_accessor :coin, :headers, :unpaid_coin_amount, :workers_online, :client, :usd_amount, :hashrate, :total_paid
  def initialize()
    @coin = ARGV[0] || 'eth'
    @headers = { 'X-CMC_PRO_API_KEY' => ENV['API_KEY'].to_s }
    @unpaid_coin_amount = 0
    @workers_online = 0
    @total_paid = 0
    @usd_amount = 0
    @hashrate = 0
    initialize_twilio_info
  end

  def initialize_twilio_info
    @account_sid = ENV['ACCT_SID']
    @auth_token = ENV['AUTH_TOKEN']
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)
  end

  def run
    get_etherminer_info
    get_total_paid
    get_coinmarket_cap_data
    send_sms
  end

  private

  def get_etherminer_info
    response = HTTParty.get("https://api.ethermine.org/miner/#{ENV['ETH']}/currentStats").parsed_response['data']
    self.hashrate = (response['reportedHashrate']/1000000).to_s + ' MH'
    self.unpaid_coin_amount = number_to_human(response['unpaid']/1000000000000000000.00, precision: 4)
    self.workers_online = response['activeWorkers']
  end

  def get_total_paid
    response = HTTParty.get("https://api.ethermine.org/miner/#{ENV['ETH']}/payouts").parsed_response['data']
    self.total_paid = number_to_human(response.map{ |n| n['amount']}.sum/1000000000000000000.00, precision: 4)
  end

  def get_coinmarket_cap_data
    data = {'convert' => 'USD', 'amount' => "#{self.unpaid_coin_amount}", 'symbol'=>"#{self.coin.upcase}"}
    coin_data = HTTParty.get(ENV['API'], query: data, headers: self.headers).parsed_response
    self.usd_amount = number_to_human(coin_data['data']['quote']['USD']['price'],precision: 4)
  end
  
  def send_sms
    if self.workers_online > 0
      client = Twilio::REST::Client.new(ENV['ACCT_SID'], ENV['AUTH_TOKEN'])
      client.messages.create(from: ENV['FROM'], to: ENV['TO'], body: "Total #{self.coin}: #{self.total_paid} \n Workers Online: #{workers_online} \n USD: $#{self.usd_amount} \n Hashrate: #{hashrate}")
    end
  end
end

f2pool = Etherminer.new
f2pool.run
