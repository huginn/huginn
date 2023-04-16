$(() =>
  $(".tweet-body").each(function () {
    return $(this).click(function () {
      $(this).off("click");
      return twttr.widgets
        .createTweet(
          this.dataset.tweetId,
          this
          // conversation: 'none'
          // cards: 'hidden'
        )
        .then((el) => (el.previousSibling.style.display = "none"));
    });
  })
);
