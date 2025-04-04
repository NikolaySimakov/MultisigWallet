// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract MultiSigWallet is Initializable, ReentrancyGuard {

		address[] public owners;
    uint256 public requiredConfirmations;
    uint256 public transactionCount;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event Submission(uint256 transactionId);
    event Confirmation(address owner, uint256 transactionId);
    event Revocation(address owner, uint256 transactionId);
    event Execution(uint256 transactionId);
    event ExecutionFailure(uint256 transactionId);

    modifier onlyOwners() {
        require(isOwner(msg.sender), "Not an owner");
        _;
    }

    modifier confirmed(uint256 _transactionId) {
        require(confirmations[_transactionId][msg.sender], "Not confirmed");
        _;
    }

    modifier notConfirmed(uint256 _transactionId) {
        require(!confirmations[_transactionId][msg.sender], "Already confirmed");
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Must have at least one owner.");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "Invalid required confirmations.");

        owners = _owners;
        requiredConfirmations = _requiredConfirmations;
    }

    function isOwner(address _address) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function submitTransaction(address _destination, uint256 _value, bytes memory _data) public onlyOwners returns (uint256) {
        transactionCount++;
        uint256 transactionId = transactionCount;

        transactions[transactionId] = Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        });

        emit Submission(transactionId);
        return transactionId;
    }

		function confirmTransaction(uint256 _transactionId) public onlyOwners notConfirmed(_transactionId) notExecuted(_transactionId) {
        confirmations[_transactionId][msg.sender] = true;
        transactions[_transactionId].confirmations++;

        emit Confirmation(msg.sender, _transactionId);

        if (transactions[_transactionId].confirmations >= requiredConfirmations) {
            executeTransaction(_transactionId);
        }
    }

    function revokeConfirmation(uint256 _transactionId) public onlyOwners confirmed(_transactionId) notExecuted(_transactionId) {
        confirmations[_transactionId][msg.sender] = false;
        transactions[_transactionId].confirmations--;

        emit Revocation(msg.sender, _transactionId);
    }

    function executeTransaction(uint256 _transactionId) internal notExecuted(_transactionId) {
        Transaction storage transaction = transactions[_transactionId];

        (bool success, ) = transaction.destination.call{value: transaction.value}(transaction.data);

        if (success) {
            transaction.executed = true;
            emit Execution(_transactionId);
        } else {
            emit ExecutionFailure(_transactionId);
        }
    }

    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }

    function getConfirmationCount(uint256 _transactionId) public view returns (uint256) {
        return transactions[_transactionId].confirmations;
    }

    function getConfirmations(uint256 _transactionId) public view returns (address[] memory) {
        address[] memory confirmedAddresses = new address[](owners.length);
        uint256 confirmationIndex = 0;

        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_transactionId][owners[i]]) {
                confirmedAddresses[confirmationIndex] = owners[i];
                confirmationIndex++;
            }
        }

        address[] memory result = new address[](confirmationIndex);
        for (uint256 i = 0; i < confirmationIndex; i++) {
            result[i] = confirmedAddresses[i];
        }

        return result;
    }

		function getTransaction(uint256 _transactionId) public view returns (Transaction memory) {
        return transactions[_transactionId];
    }

    function getTransactionIds(uint256 _from, uint256 _to, bool _pending, bool _executed) public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_to - _from);
        uint256 resultIndex = 0;

        for (uint256 i = _from; i <= _to; i++) {
            if (i > transactionCount) {
                break;
            }

            if (_pending && !transactions[i].executed) {
                result[resultIndex] = i;
                resultIndex++;
            }

            if (_executed && transactions[i].executed) {
                result[resultIndex] = i;
                resultIndex++;
            }
        }

        uint256[] memory finalResult = new uint256[](resultIndex);
        for (uint256 i = 0; i < resultIndex; i++) {
            finalResult[i] = result[i];
        }

        return finalResult;
    }

    receive() external payable {}

}