##
# the satisfaction model

class Satisfaction < ApplicationRecord

  belongs_to :folder

  belongs_to :user

  belongs_to :poll 

  validates :folder_id, presence: true

  validates :poll_id, presence: true

  ##
  # Not used
  def moy(annee)
    @Satisfactions = Satisfaction.all
    total = 0
    i = 0

    @Satisfactions.each do |s|
      if s.created_at.year == annee
        total += moyparams(s)
        i += 1
      end
    end

    if i != 0 
      result = (total / i ).to_f.round(2)
    end
  end

  ##
  # Not used 
  def moyparams(sat)
    total = 0
    totalnil = 0
    for i in 1..20
      if sat.public_send("closed#{i}") == nil 
        totalnil += 1
      else
        total += sat.public_send("closed#{i}")
      end
    end
    result = total.to_f / ( 20 - totalnil )
  end
end
