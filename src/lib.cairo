#[starknet::interface]
trait IERC721<TContractState> {
    fn transfer_from(ref self: TContractState, from: starknet::ContractAddress, to: starknet::ContractAddress, token_id: u256);
}

#[starknet::interface]
trait IAuction<TContractState> {
    fn place_bid(ref self: TContractState) -> bool;
    fn end_auction(ref self: TContractState) -> bool;
    fn get_highest_bid(self: @TContractState) -> u256;
    fn get_highest_bidder(self: @TContractState) -> starknet::ContractAddress;
    fn get_end_time(self: @TContractState) -> u64;
    fn is_ended(self: @TContractState) -> bool;
}

#[starknet::contract]
mod NFTAuction {
    use core::starknet::ContractAddress;
    use starknet::{get_block_timestamp, get_caller_address};
    use super::{IERC721Dispatcher, IERC721DispatcherTrait};

    #[storage]
    struct Storage {
        nft_contract: ContractAddress,
        token_id: u256,
        seller: ContractAddress,
        end_time: u64,
        highest_bid: u256,
        highest_bidder: ContractAddress,
        ended: bool,
        bids: starknet::storage::Map::<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BidPlaced: BidPlaced,
        AuctionEnded: AuctionEnded,
    }

    #[derive(Drop, starknet::Event)]
    struct BidPlaced {
        bidder: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AuctionEnded {
        winner: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        duration: u64,
    ) {
        let seller = get_caller_address();
        let end_time = get_block_timestamp() + duration;
        
        self.nft_contract.write(nft_contract);
        self.token_id.write(token_id);
        self.seller.write(seller);
        self.end_time.write(end_time);
        self.ended.write(false);
    }

    #[abi(embed_v0)]
    impl AuctionImpl of super::IAuction<ContractState> {
        fn place_bid(ref self: ContractState) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let end_time = self.end_time.read();
            let current_highest_bid = self.highest_bid.read();
            
            assert(!self.ended.read(), 'Auction already ended');
            assert(current_time < end_time, 'Auction already ended');
            
            let bid_amount = 10000;
            
            assert(bid_amount > current_highest_bid, 'Bid too low');
            
            self.bids.write(caller, bid_amount);
            self.highest_bid.write(bid_amount);
            self.highest_bidder.write(caller);
            
            self.emit(Event::BidPlaced(BidPlaced { bidder: caller, amount: bid_amount }));
            true
        }

        fn end_auction(ref self: ContractState) -> bool {
            let current_time = get_block_timestamp();
            let end_time = self.end_time.read();
            
            assert(!self.ended.read(), 'Auction already ended');
            assert(current_time >= end_time, 'Auction still active');
            
            self.ended.write(true);
            
            let winner = self.highest_bidder.read();
            let winning_bid = self.highest_bid.read();
            
            let nft_contract = IERC721Dispatcher { contract_address: self.nft_contract.read() };
            nft_contract.transfer_from(self.seller.read(), winner, self.token_id.read());
            
            self.emit(Event::AuctionEnded(AuctionEnded { winner, amount: winning_bid }));
            true
        }

        fn get_highest_bid(self: @ContractState) -> u256 {
            self.highest_bid.read()
        }

        fn get_highest_bidder(self: @ContractState) -> ContractAddress {
            self.highest_bidder.read()
        }

        fn get_end_time(self: @ContractState) -> u64 {
            self.end_time.read()
        }

        fn is_ended(self: @ContractState) -> bool {
            self.ended.read()
        }
    }
}