// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "./IRoomShare.sol";

contract RoomShare is IRoomShare {

  uint256 nextRoomId = 0;
  uint256 nextRentId = 0;
  mapping(uint256 => Room) private rooms;
  mapping(address => Rent[]) private rentsByUserId;
  mapping(uint256 => Rent[]) private rentsByRoomId;

  function getMyRents() external view returns(Rent[] memory) {
    /* 함수를 호출한 유저의 대여 목록을 가져온다. */
    
    return rentsByUserId[msg.sender];
  }

  function getAllRooms() external view returns(Room[] memory) {
    Room[] memory result = new Room[](nextRoomId);
    for (uint i = 0; i < nextRoomId; i++) {
      result[i] = rooms[i];
    }
    return result;
  }

  function getRoomRentHistory(uint _roomId) external view returns(Rent[] memory) {
    /* 특정 방의 대여 히스토리를 보여준다. */
    return rentsByRoomId[_roomId];
  }

  function shareRoom( string calldata name, 
                      string calldata location, 
                      uint price ) external {
    /**
     * 1. isActive 초기값은 true로 활성화, 함수를 호출한 유저가 방의 소유자이며, 365 크기의 boolean 배열을 생성하여 방 객체를 만든다.
     * 2. 방의 id와 방 객체를 매핑한다.
     */
    rooms[nextRoomId] = Room(nextRoomId, name, location, true, price, msg.sender, new bool[](365));
    emit NewRoom(nextRoomId++);
  }

  function rentRoom(uint _roomId, uint year, uint checkInDate, uint checkOutDate) payable external {
    /**
     * 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.
     *    a. 현재 활성화(isActive) 되어 있는지
     *    b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지 
     *    c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei) 
     * 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
     * *** 체크아웃 날짜에는 퇴실하여야하며, 해당일까지 숙박을 이용하려면 체크아웃날짜는 그 다음날로 변경하여야한다. ***
     */
      require(_roomId < nextRoomId, "roomId cannot found");
      
      Room memory room = rooms[_roomId];
      require(room.isActive, "this room is not active");

      for (uint i = checkInDate; i < checkOutDate; i++) {
        require(!room.isRented[i], "this room is already rented");
      }
      require(msg.value == (checkOutDate - checkInDate) * room.price * 10**15, "price is invalid");

      _sendFunds(room.owner, msg.value);
      _createRent(_roomId, year, checkInDate, checkOutDate);
  }

  function _createRent(uint256 _roomId, uint year, uint256 checkInDate, uint256 checkoutDate) internal {
    /**
     * 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
     * 2. 계정과 대여 객체들을 매핑한다. (대여 목록)
     * 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
     */
    
    for (uint i = checkInDate; i < checkoutDate; i++) {
      rooms[_roomId].isRented[i] = true;
    }
    Rent memory rent = Rent(nextRentId, _roomId, year, checkInDate, checkoutDate, msg.sender);
    rentsByUserId[rent.renter].push(rent);
    rentsByRoomId[_roomId].push(rent);

    emit NewRent(_roomId, nextRentId++);
  }

  function _sendFunds (address owner, uint256 value) internal {
      payable(owner).transfer(value);
  }
  
  

  function recommendDate(uint _roomId, uint checkInDate, uint checkOutDate) external view returns(uint[2] memory) {
    /**
    * 대여가 이미 진행되어 해당 날짜에 대여가 불가능 할 경우, 
    * 기존에 예약된 날짜가 언제부터 언제까지인지 반환한다.
    * checkInDate(체크인하려는 날짜) <= 대여된 체크인 날짜 , 대여된 체크아웃 날짜 < checkOutDate(체크아웃하려는 날짜)
    */

    Rent[] memory rents = rentsByRoomId[_roomId];
    for (uint i = 0; i < rents.length; i++) {
      Rent memory rent = rents[i];
      if (checkInDate <= rent.checkInDate && rent.checkOutDate < checkOutDate) {
        return [rent.checkInDate, rent.checkOutDate];
      }
    }

    revert("recommendDate not found");
  }

  // ...

}
