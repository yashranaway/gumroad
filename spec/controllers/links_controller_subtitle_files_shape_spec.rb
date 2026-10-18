# frozen_string_literal: true

require "spec_helper"

describe LinksController, type: :controller do
  let(:seller) { create(:user) }
  let!(:product) { create(:product, user: seller) }
  let!(:video) { create(:streamable_video, link: product, description: "original") }

  before { sign_in seller }

  def save_product(subtitle_files)
    file = { external_id: video.external_id, url: video.url, description: "renamed" }
    file[:subtitle_files] = subtitle_files unless subtitle_files.nil?
    put :update, params: { id: product.unique_permalink, files: [file] }, as: :json
  end

  # `permit` keeps a mapping under `subtitle_files` as a mapping, so `each` yields [key, value]
  # pairs and `create!` reads each pair as a list of records — the string key raises
  # ArgumentError and the whole save rolls back with a generic "Something went wrong".
  it "answers 422 and rolls the save back when subtitle_files is a mapping, not a list" do
    save_product({ "0" => { url: "https://new.srt", language: "English" } })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error_message"]).to eq("Subtitle files must be sent as a list.")
    expect(video.reload.description).to eq("original")
    expect(video.subtitle_files.reload.alive.count).to eq(0)
  end

  it "answers 422 when subtitle_files is a single subtitle object" do
    save_product({ url: "https://new.srt", language: "English" })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error_message"]).to eq("Subtitle files must be sent as a list.")
    expect(video.subtitle_files.reload.alive.count).to eq(0)
  end

  # `permit` drops the entries of a list of strings (not permitted scalars) before the write, so
  # this shape never reaches create! — the guard exists for the shapes permit keeps.
  it "saves a list of strings without writing subtitles" do
    save_product(["https://new.srt"])

    expect(response).to be_successful
    expect(video.subtitle_files.reload.alive.count).to eq(0)
  end

  it "still saves a list of subtitles" do
    save_product([{ url: "https://new.srt", language: "English" }])

    expect(response).to be_successful
    expect(video.reload.description).to eq("renamed")
    expect(video.subtitle_files.reload.alive.map(&:url)).to eq(["https://new.srt"])
  end
end
