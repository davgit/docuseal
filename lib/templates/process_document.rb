# frozen_string_literal: true

module Templates
  module ProcessDocument
    DPI = 200
    FORMAT = '.jpg'
    ATTACHMENT_NAME = 'preview_images'

    PDF_CONTENT_TYPE = 'application/pdf'
    Q = 35
    MAX_WIDTH = 1400

    module_function

    def call(attachment)
      if attachment.content_type == PDF_CONTENT_TYPE
        generate_pdf_preview_images(attachment)
      elsif attachment.content_type.starts_with?('image/')
        generate_preview_image(attachment)
      end

      attachment
    end

    def generate_preview_image(attachment)
      binary = attachment.download

      ActiveStorage::Attachment.where(name: ATTACHMENT_NAME, record: attachment).destroy_all

      image = Vips::Image.new_from_buffer(binary, '')
      image = image.resize(MAX_WIDTH / image.width.to_f)

      io = StringIO.new(image.write_to_buffer(FORMAT, Q: Q))

      ActiveStorage::Attachment.create!(
        blob: ActiveStorage::Blob.create_and_upload!(
          io:, filename: "0#{FORMAT}",
          metadata: { analyzed: true, identified: true, width: image.width, height: image.height }
        ),
        name: ATTACHMENT_NAME,
        record: attachment
      )
    end

    def generate_pdf_preview_images(attachment)
      binary = attachment.download

      ActiveStorage::Attachment.where(name: ATTACHMENT_NAME, record: attachment).destroy_all

      (0..).each do |page_number|
        page = Vips::Image.new_from_buffer(binary, '', dpi: DPI, page: page_number)
        page = page.resize(MAX_WIDTH / page.width.to_f)

        io = StringIO.new(page.write_to_buffer(FORMAT, Q: Q))

        ActiveStorage::Attachment.create!(
          blob: ActiveStorage::Blob.create_and_upload!(
            io:, filename: "#{page_number}#{FORMAT}",
            metadata: { analyzed: true, identified: true, width: page.width, height: page.height }
          ),
          name: ATTACHMENT_NAME,
          record: attachment
        )
      rescue Vips::Error
        break
      end
    end
  end
end