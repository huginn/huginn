$ ->
  $('.tweet-body').each ->
    $(this).click ->
      $(this).off('click')
      twttr.widgets.createTweet(
        this.dataset.tweetId
        this
        # conversation: 'none'
        # cards: 'hidden'
      ).then (el) ->
        el.previousSibling.style.display = 'none'
