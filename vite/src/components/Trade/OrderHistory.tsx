import { FC, useState } from "react";
import OrderHistoryCard from "./OrderHistoryCard";

const cards = [
  [1, 2, 3, 4, 5, 6, 7, 8],
  [1, 2],
  [1, 2, 3, 4],
];

const OrderHistory: FC = () => {
  const [selectedMenu, setSelectedMenu] = useState<number>(0);
  const [height, setHeight] = useState<number>(300);
  return (
    <div className="flex flex-col w-full bg-[#131722] text-[#72768f] font-semibold border-t-[0.6px] border-[#363A45] overflow-hidden">
      <div className="flex justify-between w-full h-12 items-center px-4 border-b-[0.6px] border-[#363A45] ">
        <div className="flex gap-4 ">
          <button
            className={`${selectedMenu === 0 ? "text-[#729aff]" : ""}`}
            onClick={() => setSelectedMenu(0)}
          >
            Position (8)
          </button>
          <button
            className={`${selectedMenu === 1 ? "text-[#729aff]" : ""}`}
            onClick={() => setSelectedMenu(1)}
          >
            Order (2)
          </button>
          <button
            className={`${selectedMenu === 2 ? "text-[#729aff]" : ""}`}
            onClick={() => setSelectedMenu(2)}
          >
            History
          </button>
        </div>
        <div className="flex">
          <button className="text-[#729aff]">Close All</button>
          <div className="h-6 mx-4"></div>
          <button>All My Position &gt;</button>
        </div>
      </div>
      <div className="overflow-y-auto" style={{ height }}>
        {cards[selectedMenu].map((_, i) => (
          <OrderHistoryCard key={i} type={selectedMenu} />
        ))}
      </div>
    </div>
  );
};

export default OrderHistory;