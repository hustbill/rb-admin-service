module ProductsHelpers

  #@param[obj] ActiveRecord
  def generate_hash_data(obj, method = :name)
    obj.inject({}) { |result, item| result.update(item.send(method.to_sym) =>item.id) }
  end

  def catalog_id_role_id_exist?(catalog_id, role_id)
    catalog_ids = ::Catalog.all.map(&:id)
    role_ids    = ::Role.all.map(&:id)
    catalog_ids.include?(catalog_id.to_i) && role_ids.include?(role_id.to_i)
  end

  def product_detail
    {
      tax_categories:      generate_hash_data(TaxCategory.all, :description),
      shipping_categories: generate_hash_data(ShippingCategory.all),
      countries:           Country.all_clientactive.inject([]){|r, i| r.push({id: i.id,name: i.name})},
      taxons:              Taxon.sort_groups,
      option_types:        OptionType.all.map{|ot| ot.attributes.merge(option_values: ot.product_option_values)},
      catalogs:            generate_hash_data(Catalog.active),
      roles:               generate_hash_data(Role.frontend),
      country_shipping_methods: ShippingMethod.where('display_on is null or display_on != ?', 'none').map(&:attributes)
    }
  end

  def order_sort_by(field, type = 'desc')
    if field && type
      "#{field} #{type}"
    else
      'id desc'
    end
  end

  #@param[personalized_types] => { "1"=>{"require"=>"true"}, "3"=>{"require"=>"true"} }
  def update_personalized_types(product, personalized_types)
    if personalized_types.blank?
      product.active_personalized_types_products.update_all deleted_at: Time.now
      return
    end
    old_pt = product.active_personalized_types.map(&:id).sort
    new_pt = personalized_types.keys.map(&:to_i).sort

    if old_pt == new_pt
      product.active_personalized_types_products.each do |apt|
        is_require = apt.required ? 'true' : 'false'
        if is_require != personalized_types[apt.id.to_s]['require']
          apt.update_column 'required', personalized_types[apt.id.to_s]['require']
        end
      end
    else
      personalized_types.each_pair do |k, v|
        pt = product.personalized_types_products.find_by(personalized_type_id: k)
        pt.update_column('required', v['require']) if pt
      end
      #will add
      (new_pt - old_pt).each do |pt_id|
        pt = product.personalized_types_products.find_by(personalized_type_id: pt_id)
        if pt
          pt.update_attributes deleted_at: nil, required: personalized_types[pt_id.to_s]['require']
        else
          ptp = PersonalizedTypesProduct.new(
            personalized_type_id: pt_id,
            required: personalized_types[pt_id.to_s]['require']
          )
          product.personalized_types_products << ptp
        end
      end
      #will delete
      (old_pt - new_pt).each do |pt_id|
        pt = product.personalized_types_products.find_by(personalized_type_id: pt_id)
        if pt
          pt.update_column('deleted_at', Time.now)
        end
      end
    end #if
  end

  def create_product_shipping_fee(product, opts = {})
    if opts.present? && opts.respond_to?(:each_pair)
      opts.each_pair do |key, value|
        case value['fee_type']
        when 'Calculator::SingleProductShipFlatRate'
          calculator = create_calculator_for_product(value)
          create_preference_for_product('amount', product.id, calculator.id, value)
        when 'Calculator::SingleProductShipQuantityRate'
          calculator = create_calculator_for_product(value)
          %w[shipping_fees].each do |tt|
            create_preference_for_product(tt, product.id, calculator.id, value)
          end
        else
        end #case
      end #each_pair
    end #if
  rescue
    puts 'create calculator or preference failed.'
  end

  def update_product_shipping_fee(product, opts = {})
    if opts.blank?
      product.shipping_fees.map(&:calculator).uniq.each do |calculator|
        calculator.update_attribute('deleted_at', Time.now)
      end
      product.shipping_fees.update_all(deleted_at: Time.now)
      return
    end

    if opts.present? && opts.respond_to?(:each_pair)
      old_ship = product.shipping_fees.map(&:calculator).map(&:calculable_id).uniq.sort
      new_ship = opts.keys.map(&:to_i).sort
      shiping_fees      = product.shipping_fees
      all_shipping_fees = product.shipping_fees_all
      calculators       = product.shipping_fees.map(&:calculator)

      if old_ship == new_ship
        opts.each_pair do |key, value|
          if value['fee_type'].present? && value['fee_value'].present?
            new_calculator = create_calculator_for_product(value)
            create_preference_by_diff_calculator(value, all_shipping_fees, new_calculator, product)
          end #if
        end #each_pair
      else
        #will add
        (new_ship - old_ship).each do |shipping_method_id|
          will_add = opts[shipping_method_id.to_s]
          if will_add.present? && will_add.try(:[], 'fee_type').present? && will_add.try(:[], 'fee_value').present?
            new_calculator = create_calculator_for_product(will_add)
            create_preference_by_diff_calculator(will_add, all_shipping_fees, new_calculator, product)
          end
        end

        #will delete_at
        (old_ship - new_ship).each do |shipping_method_id|
          calculator = calculators.select{|c| c.calculable_id == shipping_method_id}.first
          if calculator
            calculator.update_attribute('deleted_at', Time.now)
            shiping_fees.where(group_id: calculator.id).update_all(deleted_at: Time.now)
          end
        end

        #
        (old_ship & new_ship).each do |shipping_method_id|
          will_add = opts[shipping_method_id.to_s]
          if will_add.present? && will_add.try(:[], 'fee_type').present? && will_add.try(:[], 'fee_value').present?
            new_calculator = create_calculator_for_product(will_add)
            create_preference_by_diff_calculator(will_add, all_shipping_fees, new_calculator, product)
          end
        end
      end #if

    end #if
  rescue
    puts 'update calculator or preference failed.'
  end

  def find_exist_calculator(value = {})
    ::Calculator.where(
        calculable_id:   value['shipping_method_id'].to_i,
        calculable_type: 'ShippingMethod',
        type:            value['fee_type']
    )
  end

  def create_calculator_for_product(value = {})
    calculator = find_exist_calculator(value).first
    if calculator
      calculator.update_attribute('deleted_at', nil) if calculator.deleted_at
    else
      name = {'Calculator::SingleProductShipFlatRate'     => 'Flat Rate',
              'Calculator::SingleProductShipQuantityRate' => 'Variable Quantity Rate'}
      calculator = ::Calculator.create(
          calculable_id:   value['shipping_method_id'].to_i,
          calculable_type: 'ShippingMethod',
          type:            value['fee_type'],
          name:            name[value['fee_type']]
      )
    end
    calculator
  end

  def create_preference_for_product(name, product_id, calculator_id, value = {})
    ::Preference.new(
        name:       name,
        owner_id:   product_id,
        owner_type: 'Product',
        group_id:   calculator_id,
        group_type: 'Calculator',
        value:      (value['fee_value'][name] rescue nil)
    ).save
  end

  def create_preference_by_diff_calculator(value, all_shipping_fees, new_calculator, product)
    case value['fee_type']
    when 'Calculator::SingleProductShipFlatRate'
      shipping_fee   = all_shipping_fees.find_by(group_id: new_calculator.id, name: 'amount')
      if shipping_fee
        shipping_fee.update_attributes(value: value['fee_value'].try(:[], 'amount'), deleted_at: nil)
      else
        create_preference_for_product('amount', product.id, new_calculator.id, value)
      end
      other_calculator = find_exist_calculator({'shipping_method_id' => value['shipping_method_id'], 'fee_type' => 'Calculator::SingleProductShipQuantityRate'}).first
      other_calculator && all_shipping_fees.where(group_id: other_calculator.id, name: ['shipping_fees']).update_all(deleted_at: Time.now)
    when 'Calculator::SingleProductShipQuantityRate'
      %w[shipping_fees].each do |name|
        shipping_fee = all_shipping_fees.find_by(name: name, group_id: new_calculator.id)
        if shipping_fee
          shipping_fee.update_attributes(value: value['fee_value'].try(:[], name), deleted_at: nil)
        else
          create_preference_for_product(name, product.id, new_calculator.id, value)
        end
      end
      other_calculator = find_exist_calculator({'shipping_method_id' => value['shipping_method_id'], 'fee_type' => 'Calculator::SingleProductShipFlatRate'}).first
      other_calculator && all_shipping_fees.where(group_id: other_calculator.id, name: 'amount').update_all(deleted_at: Time.now)
    else
      #
    end
  end

  def update_wnp_product_additional_details(product, additional_details)
    if additional_details.present?
      product_additional_desc = product.product_additional_details
      additional_details.each_pair do |k, opts|
        desc = product_additional_desc.select {|d| d.name == opts['name']}.first
        if desc
          desc.update_attributes(opts)
        else
          pad = ProductAdditionalDetail.new(opts)
          pad.product_id = product.id
          pad.save
        end
      end
    end
  end

end