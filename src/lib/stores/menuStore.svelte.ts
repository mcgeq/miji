let openMenuSrialNum = $state<string>('');

const setMenuSerialNum = (serialNum: string) => {
  openMenuSrialNum = serialNum;
};

const getMenuSerialNum = () => {
  return openMenuSrialNum;
};

export const menuStore = {
  setMenuSerialNum,
  getMenuSerialNum,
};
