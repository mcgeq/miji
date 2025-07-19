import {
  Activity,
  Apple,
  Bed,
  Clock,
  CupSoda,
  Flame,
  Heart,
  Leaf,
  Moon,
  Salad,
  Sun,
} from 'lucide-vue-next';
import { PeriodPhase } from '@/schema/health/period';

// Define tip structure
export interface Tip {
  id: number;
  icon: any; // lucide-vue-next icon component
  text: string;
}

// Mapping of phase-specific tips
export const phaseTips: Record<PeriodPhase, Tip[]> = {
  Menstrual: [
    { id: 1, icon: CupSoda, text: '多喝温水，避免冷饮以缓解经期不适' },
    { id: 2, icon: Bed, text: '充分休息，避免剧烈运动以保护身体' },
    { id: 3, icon: Flame, text: '注意腹部保暖，促进血液循环' },
  ],
  Follicular: [
    { id: 1, icon: Sun, text: '增加户外活动，吸收维生素D' },
    { id: 2, icon: Salad, text: '多吃富含维生素B的食物，增强能量' },
    { id: 3, icon: Activity, text: '适度有氧运动，促进卵泡发育' },
  ],
  Ovulation: [
    { id: 1, icon: Heart, text: '注意个人卫生，保持身体清洁' },
    { id: 2, icon: Activity, text: '适量运动，提升身体活力' },
    { id: 3, icon: Leaf, text: '多吃新鲜蔬果，补充抗氧化剂' },
  ],
  Luteal: [
    { id: 1, icon: Moon, text: '规律作息，缓解经前综合症' },
    { id: 2, icon: Apple, text: '摄入高纤维食物，改善消化' },
    { id: 3, icon: Clock, text: '避免咖啡因，减少焦虑感' },
  ],
};
