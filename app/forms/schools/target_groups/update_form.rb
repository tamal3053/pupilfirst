module Schools
  module TargetGroups
    class UpdateForm < Reform::Form
      property :name, validates: { presence: true, length: { maximum: 250 } }
      property :description, validates: { presence: true, length: { maximum: 250 } }
      property :sort_index, validates: { presence: true }
      property :milestone,  validates: { presence: true }

      validate :at_least_one_milestone_tg_exists

      private

      def target_group
        @target_group ||= TargetGroup.find_by(id: id)
      end

      def level
        @level ||= target_group.level
      end

      def at_least_one_milestone_tg_exists
        return unless milestone.to_i.zero?

        return if level.target_groups.where(milestone: 'true').count > 1

        errors[:base] << 'At least one  target group must be milestone'
      end
    end
  end
end