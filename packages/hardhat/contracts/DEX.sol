// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons.
 * These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this challenge.
 * Also return variable names need to be specified exactly may be referenced (It may be helpful to cross reference with front-end code function calls).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    IERC20 token; //instantiates the imported contract
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(address swapper, uint256 tokenOutput, uint256 ethInput);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(address swapper, uint256 tokensInput, uint256 ethOutput);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(address liquidityProvider, uint256 tokensInput, uint256 ethInput, uint256 liquidityMinted);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(
        address liquidityRemover,
        uint256 tokensOutput,
        uint256 ethOutput,
        uint256 liquidityWithdrawn
    );

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) public {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the
     * erc20 contract mintee
     * (and only them based on how Balloons.sol is written).
     * Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of
     * LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the
     * totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
      require(totalLiquidity == 0, "DEX: init - Already has liquidity");
      
      totalLiquidity = address(this).balance;
      liquidity[msg.sender] = totalLiquidity;

      bool transferred = token.transferFrom(msg.sender, address(this), tokens);
      require(transferred, "DEX: init - Unable to transfer $BAL tokens to DEX");
      
      return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * You may need to update the Solidity syntax
     * (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 xInputWithFee = xInput * 997;
        uint256 numerator = xInputWithFee * yReserves;
        uint256 denominator = (xReserves * 1000) + xInputWithFee;
        return (numerator / denominator);
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
      require(msg.value > 0, "DEX: ethToToken - cannot swap 0 ETH");
      uint256 receivedEth = msg.value;
      uint256 ethReserve = address(this).balance - msg.value; // because sent eth is already included in balance
      uint256 balReserve = token.balanceOf(address(this));

      uint256 balToSend = price(receivedEth, ethReserve, balReserve);
      token.transfer(msg.sender, balToSend);
      emit EthToTokenSwap(msg.sender, balToSend, msg.value);
      return balToSend;
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
      require(tokenInput > 0, "DEX: tokenInput - cannot swap 0 tokens");
      uint256 receivedBal = tokenInput;
      uint256 balReserve = token.balanceOf(address(this));
      uint256 ethReserve = address(this).balance;

      uint ethToSend = price(receivedBal, balReserve, ethReserve);
      token.transferFrom(msg.sender, address(this), receivedBal);
      (bool sent,) = msg.sender.call{value: ethToSend}("");
      require(sent, "DEX: tokenToEth - unable to send eth");
      emit TokenToEthSwap(msg.sender, tokenInput, ethToSend);
      return ethToSend;
    }

    /**
     * @notice returns liquidity for a user.
     * NOTE: this is not needed typically due to the `liquidity()`
     * mapping variable being public and having a getter as a result.
     * This is left though as it is used within the front end code (App.jsx).
     * NOTE: if you are using a mapping liquidity, then you can use
     * `return liquidity[lp]` to get the liquidity for a user.
     * NOTE: if you will be submitting the challenge make sure to
     * implement this function as it is used in the tests.
     */
    function getLiquidity(address lp) public view returns (uint256) {
      return liquidity[lp];
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call.
     * That amount is used to determine the amount of $BAL needed as well
     * and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their
     * tokens on their behalf by calling approve function prior to
     * this function call.
     * NOTE: Equal parts of both assets will be removed from the
     * user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
      require(msg.value > 0, "DEX: deposit - no ETH sent");

      uint256 ethReserves = address(this).balance - msg.value;
      uint256 balReserves = token.balanceOf(address(this));

      // $BAL tokens deposited according to current ratio
      // add one because worst case the ratio results in zero
      uint256 balDeposit = (msg.value * balReserves/ethReserves) + 1; 

      // Liquidity minted according to ratio of total liquidity to eth
      uint256 mintedLPTokens = msg.value * (totalLiquidity / ethReserves);
      totalLiquidity += mintedLPTokens;
      liquidity[msg.sender] += mintedLPTokens;

      bool transferred = token.transferFrom(msg.sender, address(this), balDeposit);
      require(transferred, "DEX: deposit - unable to deposit tokens");

      emit LiquidityProvided(msg.sender, balDeposit, msg.value, mintedLPTokens);
      return balDeposit;
    }

    
    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up
     * getting very little back if the liquidity is super low in the pool.
     * I guess they could see that with the UI.
     */
    function withdraw(uint256 amount) public returns (uint256 eth_amount, uint256 token_amount) {
      require(
	      liquidity[msg.sender] >= amount,
	      "DEX: withdraw - liquidity less than requested amount"
	      );

      uint256 ethReserves = address(this).balance;
      uint256 balReserves = token.balanceOf(address(this));
      
      uint256 ethWithdrawal = amount * (ethReserves / totalLiquidity);
      uint256 balWithdrawal = amount * (balReserves / totalLiquidity);

      liquidity[msg.sender] -= amount;
      totalLiquidity -= amount;

      (bool sent,) = msg.sender.call{value: ethWithdrawal}("");
      require(sent, "DEX: withdraw - unable to send ETH");

      bool transferred = token.transfer(msg.sender, balWithdrawal);
      require(transferred, "DEX: withdraw - unable to transfer tokens");

      emit LiquidityRemoved(
        msg.sender,
        balWithdrawal,
        ethWithdrawal,
        amount
      );

      return (ethWithdrawal, balWithdrawal);
    }
}
