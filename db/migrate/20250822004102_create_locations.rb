class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name
      t.decimal :lat
      t.decimal :lon
      t.string :forecast_office
      t.integer :grid_x
      t.integer :grid_y

      t.timestamps
    end
  end
end
