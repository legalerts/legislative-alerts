class User < ApplicationRecord
  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/

  attr_accessor :oauth_callback
  attr_accessor :current_password
    
  validates_presence_of   :email, if: :email_required?
  validates_uniqueness_of :email, allow_blank: true, if: :email_changed?
  validates_format_of :email, :without => TEMP_EMAIL_REGEX, on: :update

  validates_presence_of     :password, if: :password_required?
  validates_confirmation_of :password, if: :password_required?
  validates_length_of       :password, within: Devise.password_length, allow_blank: true

  has_many :identities, dependent: :destroy
  has_many :alerts, dependent: :destroy

  enum role: [:user, :admin]

  devise :omniauthable,
         :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :trackable,
         omniauth_providers: [:github, :twitter, :google_oauth2]

  def self.find_for_oauth(auth, signed_in_resource = nil)

    # Get the identity and user if they exist
    identity = Identity.find_for_oauth(auth)

    # If a signed_in_resource is provided it always overrides the existing user
    # to prevent the identity being locked with accidentally created accounts.
    # Note that this may leave zombie accounts (with no associated identity) which
    # can be cleaned up at a later date.
    user = signed_in_resource ? signed_in_resource : identity.user

    # Create the user if needed
    if user.nil?

      # Get the existing user by email if the provider gives us a verified email.
      # If no verified email was provided we assign a temporary email and ask the
      # user to verify it on the next step via UsersController.finish_signup
      email = auth.info.email
      user = User.where(email: email).first if email

      # Create the user if it's a new registration
      if user.nil?
        user = User.new(
          email: email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
          password: Devise.friendly_token[0,20]  # we don't actually allow pw login
        )
        user.save!
      end
    end

    # Associate the identity with the user if needed
    if identity.user != user
      old_user_id = identity.user_id
      identity.user = user
      identity.save!

      # clean up the old user so it is not orphaned.
      if old_user_id
        old_user = User.find(old_user_id)
        if !old_user.identities.any?
          old_user.destroy
        end
      end
    end
    user
  end

  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end

  def password_required?
    return false if email.blank? || !email_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  def email_required?
    @oauth_callback != true
  end

  def emails
    identities.pluck(:email)
  end

  def facebook
    identities.where( :provider => "facebook" ).first
  end

  def facebook_client
    @facebook_client ||= Facebook.client( access_token: facebook.accesstoken )
  end

  def twitter
    identities.where( :provider => "twitter" ).first
  end

  def twitter_client
    @twitter_client ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_APP_ID']
      config.consumer_secret     = ENV['TWITTER_APP_SECRET']
      config.access_token        = twitter.accesstoken
      config.access_token_secret = twitter.secrettoken
    end
  end

  def github
    identities.where( :provider => "github" ).first
  end

  def github_client
    @github_client ||= Octokit::Client.new(access_token: github.accesstoken)
  end

  def google_oauth2
    identities.where( :provider => "google_oauth2" ).first
  end

  def google_oauth2_client
    @google_oauth2_client ||= GoogleAppsClient.client( google_oauth2 )
  end

  def following?(search_or_bill)
    if search_or_bill.is_a? Hash
      following_search?(search_or_bill)
    else
      following_bill?(search_or_bill)
    end
  end

  def following_bill?(bill)
    alerts.bill.select do |alert|
      alert.query =~ /#{bill.bill_id}/ || 
        alert.query =~ /#{bill.url_id}/ ||
        alert.new_bill_id == bill.url_id
    end.any?
  end

  def following_search?(query)
    pruned_query = Alert.prune_query(query)
    alerts.search.select { |alert| alert.has_query? pruned_query }.any?
  end

  def find_alert_for_bill(bill_id)
    alerts.bill.find do |alert|
      alert.query == query_for_bill(bill_id)
    end
  end

  def create_alert_for_bill(bill_params)
    Alert::Bill.create(
      user: self,
      query: query_for_bill(bill_params[:billId]),
      name: bill_params[:billName],
      description: bill_params[:billDescription],
      last_run_at: Time.zone.now,
    )
  end

  def find_alert_for_search(query)
    pruned_query = Alert.prune_query(query)
    alerts.search.find { |alert| alert.has_query? pruned_query }
  end

  def create_alert_for_search(query)
    Alert::Search.create(
      user: self,
      query: Alert.prune_query(query).to_json,
      name: Alert.humanize_query(query),
      description: 'saved search',
      last_run_at: Time.zone.now
    )
  end

  def avatar_url
    identities.select { |id| id.image.present? }.first.image
  end

  private

  def query_for_bill(bill_id)
    { os_bill_id: bill_id }.to_json
  end
end
