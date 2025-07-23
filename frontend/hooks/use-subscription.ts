import { useSubscription } from "@apollo/client";
import { useEffect, useState } from "react";
import {
	EVENT_CREATED_SUBSCRIPTION,
	SAGA_STATUS_SUBSCRIPTION,
	SYSTEM_EVENT_SUBSCRIPTION,
} from "@/lib/graphql/subscriptions";

export function useEventSubscription() {
	const [events, setEvents] = useState<any[]>([]);
	const { data, error, loading } = useSubscription(EVENT_CREATED_SUBSCRIPTION);

	useEffect(() => {
		if (data?.eventCreated) {
			setEvents((prev) => [data.eventCreated, ...prev].slice(0, 100));
		}
	}, [data]);

	return { events, error, loading };
}

export function useSagaSubscription() {
	const [sagas, setSagas] = useState<any[]>([]);
	const { data, error, loading } = useSubscription(SAGA_STATUS_SUBSCRIPTION);

	useEffect(() => {
		if (data?.sagaStatusChanged) {
			setSagas((prev) => {
				const index = prev.findIndex((s) => s.id === data.sagaStatusChanged.id);
				if (index >= 0) {
					const updated = [...prev];
					updated[index] = data.sagaStatusChanged;
					return updated;
				}
				return [data.sagaStatusChanged, ...prev].slice(0, 50);
			});
		}
	}, [data]);

	return { sagas, error, loading };
}

export function useSystemEventSubscription(eventType?: string) {
	const [messages, setMessages] = useState<any[]>([]);
	const { data, error, loading } = useSubscription(SYSTEM_EVENT_SUBSCRIPTION, {
		variables: { eventType },
		skip: !eventType,
	});

	useEffect(() => {
		if (data?.systemEvent) {
			setMessages((prev) => [data.systemEvent, ...prev].slice(0, 200));
		}
	}, [data]);

	return { messages, error, loading };
}
