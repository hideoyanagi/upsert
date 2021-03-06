require 'upsert/merge_function/postgresql'

class Upsert
  class MergeFunction
    # @private
    class PG_Connection < MergeFunction
      include Postgresql

      def execute(row)
        first_try = true
        bind_selector_values = row.selector.values.map { |v| connection.bind_value v }
        bind_setter_values = row.setter.values.map { |v| connection.bind_value v }
        begin
          connection.execute sql, (bind_selector_values + bind_setter_values)
        rescue PG::Error => pg_error
          if pg_error.message =~ /function #{name}.* does not exist/i
            if first_try
              Upsert.logger.info %{[upsert] Function #{name.inspect} went missing, trying to recreate}
              first_try = false
              create!
              retry
            else
              Upsert.logger.info %{[upsert] Failed to create function #{name.inspect} for some reason}
              raise pg_error
            end
          else
            raise pg_error
          end
        end
      end

      # strangely ? can't be used as a placeholder
      def sql
        @sql ||= begin
          bind_params = []
          1.upto(selector_keys.length + setter_keys.length) { |i| bind_params << "$#{i}" }
          %{SELECT #{name}(#{bind_params.join(', ')})}
        end
      end
    end
  end
end
