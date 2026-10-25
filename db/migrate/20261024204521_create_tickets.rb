class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :sector, null: false
      t.string :status, null: false, default: "open"
      t.datetime :finished_at

      t.timestamps
    end

    add_index :tickets, :title, unique: true
    add_check_constraint :tickets,
                         "status IN ('open', 'in_progress', 'closed')",
                         name: "tickets_status_check"
  end
end
