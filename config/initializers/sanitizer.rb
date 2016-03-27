ActionView::Base.sanitized_allowed_tags += Set.new(%w(table thead tbody tr th td))
ActionView::Base.sanitized_allowed_attributes += Set.new(%w(border cellspacing cellpadding valign))
