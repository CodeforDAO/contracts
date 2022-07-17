// SPDX-License-Identifier: MIT

import 'forge-std/Test.sol';
import 'murky/Merkle.sol';

contract Helper is Test {
    function setUpProof(uint256 i) public {
        Merkle m = new Merkle();
        bytes32[] memory data = new bytes32[](i);
        bytes32 merkleRoot;
        bytes32[] memory merkleProof;

        for (uint256 j = 0; j < i; j++) {
            data[j] = bytes32(uint256(j));
        }

        merkleRoot = m.getRoot(data);
        merkleRoot = m.getRoot(data);
        merkleProof = m.getProof(data, 2);
    }

    function testSetUpProof() public {
        setUpProof(4);
    }
}
