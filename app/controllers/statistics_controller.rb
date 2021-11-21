require 'faraday'

class StatisticsController < ApplicationController
  before_action :set_statistic, only: %i[ show edit update destroy ]

  ETH = ['ethers','web3','ganache-cli','hardhat','truffle','eth-brownie']
  AVALANCHE = ['avalanche']
  POLKDOT = ['polkadot']
  ALGORAND = ['algosdk']
  FLOW = ['flow']
  LAST_WEEK_BASE_URL = 'https://api.npmjs.org/downloads/point/last-week/'

  # GET /statistics or /statistics.json
  def index
    eth_url = LAST_WEEK_BASE_URL+ETH.join(',')
    eth_openzeppelin_url = LAST_WEEK_BASE_URL+'@openzeppelin/contracts'
    solana_solana_url = LAST_WEEK_BASE_URL+ '@solana/web3.js'
    other_url = LAST_WEEK_BASE_URL + [AVALANCHE, POLKDOT, ALGORAND, FLOW].flatten.join(',')

    @eth_statistics = Rails.cache.fetch("eth_stats", expires_in: 1.day) do
      [eth_url, eth_openzeppelin_url].map do |url|
        parse_stats(url)
      end.flatten.sort_by{|stat| -stat.downloads}
    end
    @other_statistics = Rails.cache.fetch("other_stats", expires_in: 1.day) do
      [solana_solana_url, other_url].map do |url|
        parse_stats(url)
      end.flatten.sort_by{|stat| -stat.downloads}
    end

  end

  private
  

    def parse_stats(url)
      response = Faraday.get url
      parsed_json = JSON.parse(response.body)
      # single url
      if(parsed_json.has_key?('package'))
        stat = parsed_json
        return Statistic.new(
            package: stat['package'],
            downloads: stat['downloads'],
            start_date: stat['start'],
            end_date: stat['end']
            )
      else
      # array of urls
        return parsed_json.values.map do |stat|
          Statistic.new(
            package: stat['package'],
            downloads: stat['downloads'],
            start_date: stat['start'],
            end_date: stat['end']
            )
        end
      end
    end
end
