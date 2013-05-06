module ClosureTree

  # Mixed into both classes and instances to provide easy access to the column names
  module Columns

    def parent_column_name
      closure_tree_options[:parent_column_name]
    end

    def parent_column_sym
      parent_column_name.to_sym
    end

    def has_name?
      ct_class.new.attributes.include? closure_tree_options[:name_column]
    end

    def name_column
      closure_tree_options[:name_column]
    end

    def name_sym
      name_column.to_sym
    end

    def hierarchy_table_name
      # We need to use the table_name, not something like ct_class.to_s.demodulize + "_hierarchies",
      # because they may have overridden the table name, which is what we want to be consistent with
      # in order for the schema to make sense.
      tablename = closure_tree_options[:hierarchy_table_name] ||
        remove_prefix_and_suffix(ct_table_name).singularize + "_hierarchies"

      ActiveRecord::Base.table_name_prefix + tablename + ActiveRecord::Base.table_name_suffix
    end

    def hierarchy_class_name
      closure_tree_options[:hierarchy_class_name] || ct_class.to_s + "Hierarchy"
    end

    def quoted_hierarchy_table_name
      ct_class.connection.quote_table_name hierarchy_table_name
    end

    def quoted_parent_column_name
      ct_class.connection.quote_column_name parent_column_name
    end

    def quoted_name_column
      ct_class.connection.quote_column_name name_column
    end

    def ct_quote(field)
      ct_class.connection.quote(field)
    end

    def order_option
      closure_tree_options[:order]
    end

    def with_order_option(options)
      order_option = options.delete(:order) || order_option

      return [options] unless order_option

      if ActiveRecord::VERSION::MAJOR == 4
        [lambda { order(order_option) }, options]
      else
        [options.merge(:order => order_option)]
      end
    end

    def append_order(order_by)
      order_option ? "#{order_by}, #{order_option}" : order_by
    end

    def order_is_numeric
      # The table might not exist yet (in the case of ActiveRecord::Observer use, see issue 32)
      return false if order_option.nil? || !self.table_exists?
      c = ct_class.columns_hash[order_option]
      c && c.type == :integer
    end

    def ct_class
      (self.is_a?(Class) ? self : self.class)
    end

    # This is the "topmost" class. This will only potentially not be ct_class if you are using STI.
    def ct_base_class
      ct_class.closure_tree_options[:ct_base_class]
    end

    def ct_subclass?
      ct_class != ct_class.base_class
    end

    def ct_attribute_names
      @ct_attr_names ||= ct_class.new.attributes.keys - ct_class.protected_attributes.to_a
    end

    def ct_has_type?
      ct_attribute_names.include? 'type'
    end

    def ct_table_name
      ct_class.table_name
    end

    def quoted_table_name
      ct_class.connection.quote_table_name ct_table_name
    end

    def remove_prefix_and_suffix(table_name)
      prefix = Regexp.escape(ActiveRecord::Base.table_name_prefix)
      suffix = Regexp.escape(ActiveRecord::Base.table_name_suffix)
      table_name.gsub(/^#{prefix}(.+)#{suffix}$/, "\\1")
    end
  end
end
