#becase ActiveModel::ForbiddenAttributesError
#see https://github.com/intridea/hashie/pull/125
Hashie::Mash.class_eval do
  SKIPPED_METHODS = [:permitted?]
  def respond_to?(method_name, include_private=false)
    return false if SKIPPED_METHODS.include?(method_name.to_sym)
    return true if key?(method_name) || method_name.to_s.slice(/[=?!_]\Z/)
    super
  end
end

#针对中间表有timestamp字段
module ActiveRecord
  module Associations
    class HasAndBelongsToManyAssociation
      def insert_record(record, validate = true, raise = false)
        if record.new_record?
          if raise
            record.save!(:validate => validate)
          else
            return unless record.save(:validate => validate)
          end
        end

        if options[:insert_sql]
          owner.connection.insert(interpolate(options[:insert_sql], record))
        else
          c_table_columns = reflection.columns(join_table.name) #查询中间表的所有字段
          column_opts     = {
            join_table[reflection.foreign_key]             => owner.id,
            join_table[reflection.association_foreign_key] => record.id,
          }
          c_table_columns.each do |column|
            if %w[created_at updated_at].include?(column.name)
              column_opts[join_table[column.name]] = Time.now
            end
          end
          stmt = join_table.compile_insert(column_opts)

          owner.class.connection.insert stmt
        end

        record
      end
    end
  end
end