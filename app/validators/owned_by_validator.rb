class OwnedByValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, association)
    return if association.all? {|s| s[options[:with]] == record[options[:with]] }
    record.errors[attribute] << "must be owned by you"
  end
end
