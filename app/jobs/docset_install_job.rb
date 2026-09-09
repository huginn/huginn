class DocsetInstallJob < ActiveJob::Base
  queue_as :default

  def perform(docset_id)
    docset = Docset.find(docset_id)
    Remix::Docset::Installer.new(docset).install!
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("DocsetInstallJob: Docset #{docset_id} not found: #{e.message}")
  rescue => e
    Rails.logger.error("DocsetInstallJob: Failed to install docset #{docset_id}: #{e.message}")
    # The installer already sets status to 'error', but just in case
    begin
      docset = Docset.find_by(id: docset_id)
      docset&.update(status: 'error', error_message: e.message) unless docset&.error?
    rescue => inner
      Rails.logger.error("DocsetInstallJob: Failed to update error status: #{inner.message}")
    end
  end
end
