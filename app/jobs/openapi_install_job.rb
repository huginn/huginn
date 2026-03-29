class OpenapiInstallJob < ActiveJob::Base
  queue_as :default

  def perform(docset_id)
    docset = Docset.find(docset_id)
    Remix::Openapi::Installer.new(docset).install!
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("OpenapiInstallJob: Docset #{docset_id} not found: #{e.message}")
  rescue => e
    Rails.logger.error("OpenapiInstallJob: Failed to install API spec #{docset_id}: #{e.message}")
    begin
      docset = Docset.find_by(id: docset_id)
      docset&.update(status: 'error', error_message: e.message) unless docset&.error?
    rescue => inner
      Rails.logger.error("OpenapiInstallJob: Failed to update error status: #{inner.message}")
    end
  end
end
