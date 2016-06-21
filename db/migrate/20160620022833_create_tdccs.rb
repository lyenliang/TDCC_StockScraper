class CreateTdccs < ActiveRecord::Migration
  def change
    create_table :tdccs do |t|
      t.string :stock_number
      t.date :date
      t.string :group
      t.integer :people
      t.integer :shares
      t.float :percent

      t.timestamps null: false
    end
  end
end
