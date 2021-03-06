class Alert::Bill < Alert
  def self.model_name
    Alert.model_name
  end

  def url_name
    'bills'
  end

  def os_bill
    @_os_bill ||= begin
      bill_id = parsed_query[:os_bill_id]
      if bill_id.length == 11
        bill_id = new_bill_id
      end

      fail Faraday::ResourceNotFound, id unless bill_id

      OpenStates::Bill.try_find_by_os_bill_id(bill_id, user, Rails.logger)
    rescue Faraday::ResourceNotFound => err
      # if it no longer exists, deactivate the alert
      archived!
      false
    rescue Faraday::ClientError => err
      # non-200 response of some kind. Log it and move on.
      errored!
      false
    end
  end

  def new_bill_id
    bill_id = name
    return unless description && description.match(/^\[..\ .+?\]/)
    state = description.match(/^\[(..)/)[1]
    session = description.match(/^\[..\ (.+?)\]/)[1]
    Base64.urlsafe_encode64(sprintf("%s/%s/%s", state, session, bill_id))
  end

  def os_url
    os_bill.os_url + '#actions'
  end

  def check
    if bill_has_changed?(os_bill)
      return update_as_run(os_checksum(os_bill))
    end
  end

  private

  def url_query
    '/' + parsed_query[:os_bill_id]
  end

  def bill_has_changed?(bill)
    return unless bill
    return true unless checksum # we have not checked before
    return false if bill.action_dates[:last].blank?

    Rails.logger.debug("last action date: #{bill.action_dates[:last]}")

    # most recent dates isn't always "last"
    dates = bill.action_dates.values_at('first', 'last').sort

    last_date = dates.first

    DateTime.parse(last_date) > last_run_at
  end
end
