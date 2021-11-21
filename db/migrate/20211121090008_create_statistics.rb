class CreateStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :statistics do |t|
      t.string :package
      t.integer :downloads
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
  end
end
