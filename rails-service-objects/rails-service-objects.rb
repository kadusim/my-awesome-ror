# app/services/tweet_creator.rb
class TweetCreator
  def initialize(message)
    @message = message
  end

  def send_tweet
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
      config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
      config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
      config.access_token_secret = ENV['TWITTER_ACCESS_SECRET']
    end
    client.update(@message)
  end
end

# app/services/application_service.rb
class ApplicationService
  def self.call(*args, &block)
    new(*args, &block).call
  end
end

# app/services/tweet_creator.rb
class TweetCreator < ApplicationService
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def call
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
      config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
      config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
      config.access_token_secret = ENV['TWITTER_ACCESS_SECRET']
    end
    client.update(@message)
  end
end

# app/controllers/
class TweetController < ApplicationController
  def create
    TweetCreator.call(params[:message])
  end
end

#---------------------------------------------#
# Grouping Similar Service Objects for Sanity #
#---------------------------------------------#

# services/twitter_manager/tweet_creator.rb
module TwitterManager
  class TweetCreator < ApplicationService
  ...
  end
end

# services/twitter_manager/profile_follower.rb
module TwitterManager
  class ProfileFollower < ApplicationService
  ...
  end
end

TwitterManager::TweetCreator.call(arg)
TwitterManager::ProfileManager.call(arg)

#-----------------------------------------------#
# Service Objects to Handle Database Operations #
#-----------------------------------------------#

module MoneyManager
  # exchange currency from one amount to another
  class CurrencyExchanger < ApplicationService
    ...
    def call
      ActiveRecord::Base.transaction do
        # transfer the original currency to the exchange's account
        outgoing_tx = CurrencyTransferrer.call(
          from: the_user_account,
          to: the_exchange_account,
          amount: the_amount,
          currency: original_currency
        )

        # get the exchange rate
        rate = ExchangeRateGetter.call(
          from: original_currency,
          to: new_currency
        )

        # transfer the new currency back to the user's account
        incoming_tx = CurrencyTransferrer.call(
          from: the_exchange_account,
          to: the_user_account,
          amount: the_amount * rate,
          currency: new_currency
        )

        # record the exchange happening
        ExchangeRecorder.call(
          outgoing_tx: outgoing_tx,
          incoming_tx: incoming_tx
        )
      end
    end
  end

  # record the transfer of money from one account to another in money_accounts
  class CurrencyTransferrer < ApplicationService
    ...
  end

  # record an exchange event in the money_exchanges table
  class ExchangeRecorder < ApplicationService
    ...
  end

  # get the exchange rate from an API
  class ExchangeRateGetter < ApplicationService
    ...
  end
end
