pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

//multisignature part ref.
// https://github.com/ConsenSysMesh/MultiSigWallet/blob/master/MultiSigWalletWithDailyLimit.sol

contract MyContract is ERC1155 {

    event Confirmation(address indexed sender, uint indexed transactionId);
    event Revocation(address indexed sender, uint indexed transactionId);
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    event Deposit(address indexed sender, uint value);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint required);

    string public company_name;
    address[] private owners;
    address public contract_creator;
    mapping (address => bool) private isOwner;
    
    uint public required;
    uint public transactionCount;
    
    string public founding_date;
    
     struct Transaction {
        address to;
        uint value;
        bool executed;
        uint numConfirmations;
        uint valid;
    }

    mapping (uint => Transaction) private transactions;
    mapping (uint => mapping (address => bool)) private confirmations;
    mapping (uint => mapping (address => bool)) private member_has_confirmed;


    constructor(address[] memory _owners,
     string memory _company_name,
     uint _num_board_required,
     uint _num_shares,
     string memory _founding_date) 
        public
        ERC1155("https://raw.githubusercontent.com/jongos-lst/blockchain_project/main/metadata/matadata.json")
    {
        require(_owners.length > 0, "owners required");        
        require(
            _num_board_required > 0 &&
                _num_board_required <= _owners.length,
            "invalid number of board required"
        );
        company_name = _company_name;
        required = _num_board_required;
        founding_date = _founding_date;

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            isOwner[owner] = true;
            owners.push(owner);
        }
        contract_creator = msg.sender;
        _mint(msg.sender, 0, _num_shares, "");
    }
    
    modifier isBoardMember(address addr) {
        require(isOwner[addr]);
        _;
    }
    
    modifier onlyCreator() {
        require(msg.sender == contract_creator);
        _;
    }

    modifier transactionExists(uint transactionId) {
        require (transactions[transactionId].valid == 1);
        _;
    }

    modifier confirmed(uint transactionId, address owner) {
        require (confirmations[transactionId][owner]);
        _;
    }

    modifier notConfirmed(uint transactionId, address owner) {
        require (!confirmations[transactionId][owner]);
        _;
    }

    modifier notExecuted(uint transactionId) {
        require (!transactions[transactionId].executed);
        _;
    }

    function redemptStock(address addr, uint amount) public onlyCreator{
        _burn(addr, 0, amount);
    }

    function reissueStock(address addr, uint amount) public onlyCreator{
        _mint(addr, 0, amount, "");
    }

    function stockBalances(address _addr) view public returns (uint256){
        return balanceOf(_addr, 0);
    }

    function getTransactionCount() private view returns (uint) {
        return transactionCount;
    }

    function getTransaction(uint transactionId)
        private
        view
        returns (
            address to,
            uint value,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[transactionId];
        return (
            transaction.to,
            transaction.value,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    function submitTransaction(address destination, uint value)
        public
        returns (uint transactionId)
    {
        uint remain = balanceOf(contract_creator, 0);
        require(remain >= value, "Not enough stocks for transfering");
        transactionId = addTransaction(destination, value);
        confirmTransaction(transactionId);
    }

    function confirmTransaction(uint transactionId)
        public
        isBoardMember(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        Transaction storage transaction = transactions[transactionId];
        transaction.numConfirmations += 1;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    function revokeConfirmation(uint transactionId)
        private
        isBoardMember(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }

    function executeTransaction(uint transactionId)
        private
        notExecuted(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];
        require(transaction.numConfirmations >= required, "Not enough confirmations.");

        transaction.executed = true;

        safeTransferFrom(contract_creator, transaction.to, 0, transaction.value, "");
    }

    function isConfirmed(uint transactionId)
        private
        returns (bool)
    {
        uint count = 0;
        for (uint i=0; i<owners.length; i++) {
            if (confirmations[transactionId][owners[i]])
                count += 1;
            if (count == required)
                return true;
        }
        return false;
    }

    function addTransaction(address destination, uint value)
        internal
        returns (uint transactionId)
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            to: destination,
            value: value,
            executed: false,
            numConfirmations: 0,
            valid: 1
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }
}
