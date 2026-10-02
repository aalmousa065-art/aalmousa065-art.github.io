import {env} from 'cloudflare:workers';
import {getChatGPTUser} from '../app/chatgpt-auth';
export const db=()=>env.DB as D1Database;
export const bucket=()=>env.BUCKET as R2Bucket;
export const ownerEmail=(env as unknown as {OWNER_EMAIL?:string}).OWNER_EMAIL?.toLowerCase();
export async function identity(){const user=await getChatGPTUser();const owner=!!ownerEmail && user?.email.toLowerCase()===ownerEmail;const member=user?await db().prepare('SELECT email FROM members WHERE email=?').bind(user.email.toLowerCase()).first():null;return {user,owner,contributor:owner||!!member};}
