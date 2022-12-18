function executeOperation(FlashLoan memory flashLoan)
    internal
    payable
    returns (uint256)
{
    // Ensure that the flash loan is for either WBTC or WMATIC
    require(flashLoan.asset == WBTC_TOKEN_ADDRESS || flashLoan.asset == WMATIC_TOKEN_ADDRESS, "Invalid flash loan asset");

    // Get the token decimals for the flash loan asset
    uint8 tokenDecimals = (flashLoan.asset == WBTC_TOKEN_ADDRESS) ? WBTC_TOKEN_DECIMALS : WMATIC_TOKEN_DECIMALS;

    // Calculate the amount of the flash loan asset that will be used for the arbitrage swap
    uint amount = flashLoan.principal.div(2);

    // Calculate the minimum amount of the other asset that should be received in the arbitrage swap
    uint minOutput = MIN_PROFIT.mul(amount).div(10 ** tokenDecimals);

    // Determine the addresses and ABIs for the contracts and tokens involved in the arbitrage swap
    address asset1, asset2;
    bytes32 contractABI;
    if (flashLoan.asset == WBTC_TOKEN_ADDRESS) {
        asset1 = WBTC_TOKEN_ADDRESS;
        asset2 = WMATIC_TOKEN_ADDRESS;
        contractABI = UNISWAP_V3_ROUTER_CONTRACT_ABI;
    } else {
        asset1 = WMATIC_TOKEN_ADDRESS;
        asset2 = WBTC_TOKEN_ADDRESS;
        contractABI = PARASWAP_CONTRACT_ABI;
    }

    // Send the flash loan asset to the exchange and receive the other asset in return
    (bool success, bytes memory data) =
        asset1.call.value(amount)("swapExactTokensForTokens", contractABI, minOutput, 1, asset1, address(this), asset2);
    require(success, "Failed to execute swap");

    // Parse the return value from the exchange to determine the actual amount of the other asset received
    uint[] memory returnValues = new uint[3];
    assembly {
        let size := mload(data)
        let offset := add(data, 0x20)
        for (let i := 0; i < 3; i++) {
            mstore(add(returnValues, 0x20), mload(offset))
            offset := add(offset, 0x20)
        }
    }
    uint outputAmount = returnValues[2];
