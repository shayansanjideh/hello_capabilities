module hello_capabilities::donut_shop {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    
    /// Error codes
    const ENOT_AUTHORIZED: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;
    const EALREADY_INITIALIZED: u64 = 3;
    const EINVALID_PRICE: u64 = 4;

    /// Represents the admin capability that allows withdrawing funds
    struct AdminCapability has key, store {
        shop_addr: address
    }

    /// Represents a donut token that customers receive
    struct Donut has key, store {
        flavor: vector<u8>
    }

    /// Represents the shop's state
    struct Shop has key {
        balance: u64,
        donut_price: u64,
        total_donuts_sold: u64
    }

    /// Initialize the donut shop. Can only be called once by the owner.
    public entry fun initialize_shop(
        owner: &signer,
        initial_donut_price: u64
    ) {
        let owner_addr = signer::address_of(owner);
        
        assert!(
            !exists<Shop>(owner_addr),
            EALREADY_INITIALIZED
        );
        assert!(
            initial_donut_price > 0,
            EINVALID_PRICE
        );

        // Create and store the admin capability
        move_to(owner, AdminCapability {
            shop_addr: owner_addr
        });

        // Initialize the shop's state
        move_to(owner, Shop {
            balance: 0,
            donut_price: initial_donut_price,
            total_donuts_sold: 0
        });
    }

    /// Allow customers to buy a donut by paying in AptosCoin
    public entry fun buy_donut(
        customer: &signer,
        shop_addr: address,
    ) acquires Shop {
        let shop = borrow_global_mut<Shop>(shop_addr);
        
        // Transfer the payment from customer to shop
        coin::transfer<AptosCoin>(
            customer,
            shop_addr,
            shop.donut_price
        );

        // Update shop's state
        shop.balance = shop.balance + shop.donut_price;
        shop.total_donuts_sold = shop.total_donuts_sold + 1;

        // Create and transfer donut to customer
        move_to(customer, Donut { 
            flavor: b"glazed" 
        });
    }

    /// Allow shop owner to withdraw funds. Requires AdminCapability.
    public entry fun withdraw_funds(
        admin: &signer,
        amount: u64
    ) acquires AdminCapability, Shop {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin has the capability
        assert!(
            exists<AdminCapability>(admin_addr),
            ENOT_AUTHORIZED
        );
        
        let cap = borrow_global<AdminCapability>(admin_addr);
        let shop = borrow_global_mut<Shop>(cap.shop_addr);
        
        // Verify sufficient balance
        assert!(
            amount <= shop.balance,
            EINSUFFICIENT_BALANCE
        );

        // Update shop balance and transfer funds
        shop.balance = shop.balance - amount;
        coin::transfer<AptosCoin>(
            admin,
            admin_addr,
            amount
        );
    }

    /// Allow shop owner to update donut price. Requires AdminCapability.
    public entry fun update_price(
        admin: &signer,
        new_price: u64
    ) acquires AdminCapability, Shop {
        let admin_addr = signer::address_of(admin);
        
        assert!(
            exists<AdminCapability>(admin_addr),
            ENOT_AUTHORIZED
        );
        assert!(
            new_price > 0,
            EINVALID_PRICE
        );
        
        let cap = borrow_global<AdminCapability>(admin_addr);
        let shop = borrow_global_mut<Shop>(cap.shop_addr);
        
        shop.donut_price = new_price;
    }

    // View functions
    #[view]
    public fun get_donut_price(shop_addr: address): u64 acquires Shop {
        borrow_global<Shop>(shop_addr).donut_price
    }

    #[view]
    public fun get_total_donuts_sold(shop_addr: address): u64 acquires Shop {
        borrow_global<Shop>(shop_addr).total_donuts_sold
    }

    #[view]
    public fun get_shop_balance(shop_addr: address): u64 acquires Shop {
        borrow_global<Shop>(shop_addr).balance
    }
}