import {requireChatGPTUser} from '../chatgpt-auth';
import Store from '../store';
export const dynamic='force-dynamic';
export default async function Page(){await requireChatGPTUser('/studio');return <Store studio/>}
