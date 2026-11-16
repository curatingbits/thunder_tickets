# The only seats held are Section 101, Row DD (seats 1-3). The first sales,
# loaded on 2025-10-25 before the section/row columns existed, were left
# blank and render as "Section , Row , Seat N". Section and row are display
# only; nothing totals, filters, or reports by them, so this changes no
# figures.
class BackfillTicketSectionAndRow < ActiveRecord::Migration[8.0]
  # Standalone model so the migration doesn't depend on app/models/ticket.rb
  # as it changes over time.
  class MigrationTicket < ActiveRecord::Base
    self.table_name = "tickets"
  end

  def up
    MigrationTicket.where(section: [ nil, "" ]).update_all(section: "101")
    MigrationTicket.where(row: [ nil, "" ]).update_all(row: "DD")
  end

  def down
    # Nothing to restore: the blanks carried no information.
  end
end
