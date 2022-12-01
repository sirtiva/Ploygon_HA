// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

//chainlnk contract import
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

//main contract starts
contract CoinFlip is VRFV2WrapperConsumerBase {
    event CoinFlipRequest(uint256 requestId);
    event CoinFlipResult(uint256 requestId, bool youWin);

    //declaring what the fuction tracks on being called
    struct CoinFlipStatus {
        uint256 fees;
        uint256 randomWord;
        address player;
        bool youWin;
        bool fulfilled;
        CoinFlipSelection choice;
    }

    enum CoinFlipSelection {
        EVEN,
        ODD
    }


    //mapping to check on the status of the game
    mapping(uint256 => CoinFlipStatus) public statuses;


    //addresses of the network being deployed on
    address constant linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address constant vrfWrapperAddress =
        0x708701a1DfF4f478de54383E49a627eD4852C816;

    uint128 constant entryFees = 0.001 ether;  //lowest amount to stake before playing
    uint32 constant callbackGasLimit = 1_000_000;  //gas limit when result is sent back to the contract
    uint32 constant numWords = 1;  //number of random numbers created at a time
    uint16 constant requestConfirmations = 3;  //number of confirmations before result is sent


    //last step for setting vrfcontract
    // VRFWrapper takes in contract address declared above
    constructor()
        payable
        VRFV2WrapperConsumerBase(linkAddress, vrfWrapperAddress)
    {}

    function flip(CoinFlipSelection choice) external payable returns (uint256) {
        require(msg.value == entryFees, "Send entry fee before playing");    //function to make sure user sends token before playing

        uint256 requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );

        statuses[requestId] = CoinFlipStatus({
            fees: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWord: 0,
            player: msg.sender,
            youWin: false,
            fulfilled: false,
            choice: choice
        });

        emit CoinFlipRequest(requestId);
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        
        require(statuses[requestId].fees > 0, "request not found");
        

        statuses[requestId].fulfilled = true;
        statuses[requestId].randomWord = randomWords[0];

        CoinFlipSelection result = CoinFlipSelection.ODD;
        if (randomWords[0] % 2 == 0) {
            result = CoinFlipSelection.EVEN;
        }

        if (statuses[requestId].choice == result) {
            statuses[requestId].youWin = true;
            payable(statuses[requestId].player).transfer(entryFees * 2);
        }
        randomWords = randomWords;

        emit CoinFlipResult(requestId, statuses[requestId].youWin);
    }

    function getStatus(uint256 requestId)
        public
        view
        returns (CoinFlipStatus memory)
    {
        return statuses[requestId];
    }
}