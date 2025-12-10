class CreateAudienceExportsAndChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :audience_exports do |t|
      t.references :seller, null: false
      t.references :recipient, null: false
      t.text :options
      t.timestamps
    end

    create_table :audience_export_chunks do |t|
      t.references :export, null: false
      t.text :member_ids, size: :long
      t.text :members_data, size: :long
      t.boolean :processed, default: false, null: false
      t.string :revision
      t.timestamps
    end
  end
end
