LegAlerts = {
  searchFormParams: function() {
    var form = $('#search-form');
    var params = form.serializeArray();
    var query = {};
    $.each(params, function(idx, param) {
      var matches = param.name.match(/search\[(.+)\]/);
      if (!matches) return;
      query[matches[1]] = param.value;
    });
    return query;
  },

  unfollowBill: function(btn) {
    btn.text('Follow');
    var bill_id = btn.data('billId');
    var url = '/bills/'+bill_id+'/unfollow';
    $.post(url, btn.data(), function(rsp) {
      //console.log('rsp', rsp);
    })
    .fail(function() {
      btn.text('Following');
      LegAlerts.toggleFollow(btn);
    });
  },

  unfollowSearch: function(btn) {
    btn.text('Save search as alert');
    var query = LegAlerts.searchFormParams();
    var url = '/search/unfollow';
    $.post(url, { search: query }, function(rsp) {
    })
    .fail(function() {
      btn.text('Save as alert');
      LegAlerts.toggleFollow(btn);
    });
  },

  unfollow: function(btn) {
    if (btn.attr('id') == 'search-as-alert') {
      LegAlerts.unfollowSearch(btn);
    }
    else {
      LegAlerts.unfollowBill(btn);
    }
  },

  followBill: function(btn) {
    btn.text('Following');
    var bill_id = btn.data('billId');
    var url = '/bills/'+bill_id+'/follow';
    $.post(url, btn.data(), function(rsp) {
      //console.log('rsp', rsp);
    })
    .fail(function() {
      btn.text('Follow');
      LegAlerts.toggleFollow(btn);
    });
  },

  followSearch: function(btn) {
    btn.text('Following search');
    var query = LegAlerts.searchFormParams();
    var url = '/search/follow';
    $.post(url, { search: query }, function(rsp) {
    })
    .fail(function() {
      btn.text('Save as alert');
      LegAlerts.toggleFollow(btn);
    });
  },

  follow: function(btn) {
    if (btn.attr('id') == 'search-as-alert') {
      LegAlerts.followSearch(btn);
    }
    else {
      LegAlerts.followBill(btn);
    }
  },

  toggleFollow: function(btn) {
    btn.toggleClass('following');
    btn.toggleClass('follow');
    btn.toggleClass('btn-success');
    btn.toggleClass('btn-default');
  },

  handleFollows: function(btn) {
    btn.click(function() {
      if (btn.hasClass('following')) {
        LegAlerts.unfollow(btn);
      }
      else {
        LegAlerts.follow(btn);
      }
      LegAlerts.toggleFollow(btn);
    });
  },

  showBillDetails: function(bill) {
    var modal = $('#bill-details-modal');
    modal.find('.ajax-loader').hide();
    modal.on('hide.bs.modal', function() {
      modal.find('.ajax-loader').show();
    });
    modal.find('.modal-title').html($('<a href="/bills/'+bill.url_id+'">'+bill.bill_id+'</a>'));
    var actions_html = [];
    $.each(bill.actions.reverse(), function(idx) {
      var action = this;
      var html = action.date.replace(/\ .+/, '');
      html += '<br/>' + action.action;
      actions_html.push('<div class="action">'+html+'</div>');
    });
    modal.find('.title').text(bill.title);
    modal.find('.actions').html(actions_html.join(''));
  }
}
