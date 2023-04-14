CREATE PROCEDURE income_procedure @start_send_date DATE = NULL, @end_send_date DATE = NULL, @start_activation_date DATE = NULL, @end_activation_date DATE = NULL, @operator_id INT = 0, @id_group_tarif INT = 0, @region_id INT = 0, @start_reporting_period DATE = NULL, @end_reporting_period DATE = NULL AS 
BEGIN
	WITH report_date AS 
	(
		SELECT
			id_sim,
			stuff((
			SELECT
				'|' + CONVERT(NVARCHAR(255), money) 
			FROM
				pay_bilane b 
			WHERE
				a.id_sim = b.id_sim 
			GROUP BY
				MONEY FOR XML path(''), type).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS money,
				stuff((
				SELECT
					'|' + CONVERT(NVARCHAR(255), reporting_period) 
				FROM
					pay_bilane b 
				WHERE
					a.id_sim = b.id_sim 
				GROUP BY
					reporting_period FOR XML path(''), type).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS reporting_date 
				FROM
					pay_bilane a 
				GROUP BY
					id_sim 
	)
,
	cash AS 
	(
		SELECT
			sv_name,
			round(SUM( 
			CASE
				WHEN
					MONEY IS NOT NULL 
				THEN
					COALESCE(MONEY, 0) 
			END
), 2) AS moneys 
		FROM
			sims_stats ss 
			INNER JOIN
				pay_bilane pb 
				ON ss.sim_id = pb.id_sim 
			LEFT JOIN
				tarif tf 
				ON ss.tarif_id = tf.operator_id 
			INNER JOIN
				agents ag 
				ON ss.agent_id = ag.agents_id 
			INNER JOIN
				table_agent ta 
				ON ag.agent_name = ta.id_agent 
			INNER JOIN
				supervisors sv 
				ON ta.id_supervisors = sv.supervisors_id 
		WHERE
			ss.sim_id IS NOT NULL 
			AND send_date IS NOT NULL 
			AND sv.supervisors_id IS NOT NULL 
			AND 
			(
				@start_send_date IS NULL 
				OR ss.send_date >= @start_send_date 
			)
			AND 
			(
				@end_send_date IS NULL 
				OR ss.send_date <= @end_send_date 
			)
			AND 
			(
				@operator_id = 0 
				OR tf.operator_id = @operator_id 
			)
			AND 
			(
				@id_group_tarif = 0 
				OR tf.tarifs_group = @id_group_tarif 
			)
			AND 
			(
				@region_id = 0 
				OR ss.region_id = @region_id 
			)
			AND 
			(
				@start_reporting_period IS NULL 
				OR pb.reporting_period >= @start_reporting_period 
			)
			AND 
			(
				@end_reporting_period IS NULL 
				OR pb.reporting_period <= @end_reporting_period 
			)
		GROUP BY
			sv_name 
	)
, fix_fee AS 
	(
		SELECT
			sv.sv_name,
			round(SUM( 
			CASE
				WHEN
					activation_date IS NOT NULL 
				THEN
					COALESCE(ag_salary, 0) 
			END
), 2) AS ag_salarys, round(SUM( 
			CASE
				WHEN
					activation_date IS NOT NULL 
					AND ISNULL(sv.name_url, '') <> ISNULL(ta.url_name, '') 
				THEN
					COALESCE(sv_salaty, 0) 
			END
), 2) AS sv_salarys, round(SUM( 
			CASE
				WHEN
					activation_date IS NOT NULL 
				THEN
					COALESCE(ag_bonus, 0) 
			END
), 2) AS ag_bonuss 
		FROM
			stavka_agent sa 
			INNER JOIN
				supervisors sv 
				ON sa.id_stavka_supervisors = sv.supervisors_id 
			INNER JOIN
				table_agent ta 
				ON sv.supervisors_id = ta.id_supervisors 
			INNER JOIN
				agents ag 
				ON ta.id_agent = ag.agent_name 
			INNER JOIN
				sims_stats ss 
				ON ag.agents_id = ss.agent_id 
			LEFT JOIN
				report_date rp 
				ON ss.sim_id = rp.id_sim 
			INNER JOIN
				tarif tf 
				ON ss.tarif_id = tf.tarifs_id 
			INNER JOIN
				tariff_group tg 
				ON tf.tarifs_group = tg.id_group_tariff 
		WHERE
			id_group_tariff = id_tarif_group 
			AND ss.sim_id IS NOT NULL 
			AND 
			(
				@start_send_date IS NULL 
				OR ss.send_date >= @start_send_date 
			)
			AND 
			(
				@end_send_date IS NULL 
				OR ss.send_date <= @end_send_date 
			)
			AND 
			(
				@operator_id = 0 
				OR tf.operator_id = @operator_id 
			)
			AND 
			(
				@id_group_tarif = 0 
				OR tf.tarifs_group = @id_group_tarif 
			)
			AND 
			(
				@region_id = 0 
				OR ss.region_id = @region_id 
			)
			AND 
			(
				@start_reporting_period IS NULL 
				OR rp.reporting_date >= @start_reporting_period 
			)
			AND 
			(
				@end_reporting_period IS NULL 
				OR rp.reporting_date <= @end_reporting_period 
			)
		GROUP BY
			sv.sv_name 
	)
, sims_counts AS 
	(
		SELECT
			sv_name,
			COUNT( DISTINCT 
			CASE
				WHEN
					send_date IS NOT NULL 
				THEN
					COALESCE(ss.sim_id, 0) 
			END
) AS sv_counts, COUNT( DISTINCT 
			CASE
				WHEN
					activation_date IS NOT NULL 
				THEN
					COALESCE(ss.sim_id, 0) 
			END
) AS activation_dates, CAST(COUNT(DISTINCT 
			CASE
				WHEN
					activation_date IS NOT NULL 
				THEN
					COALESCE(ss.sim_id, 0) 
			END
) * 100.0 / COUNT(DISTINCT 
			CASE
				WHEN
					send_date IS NOT NULL 
				THEN
					COALESCE(ss.sim_id, 0) 
			END
) AS DECIMAL(10, 2)) AS percentage, round(SUM( 
			CASE
				WHEN
					send_date IS NOT NULL 
				THEN
					COALESCE(purchase_price, 0) 
			END
), 2) AS purchase_prices, round(SUM( 
			CASE
				WHEN
					activation_date IS NOT NULL 
				THEN
					COALESCE(activation_cost, 0) 
			END
), 2) AS activation_costs 
		FROM
			supervisors sv 
			INNER JOIN
				table_agent ta 
				ON sv.supervisors_id = ta.id_supervisors 
			INNER JOIN
				agents ag 
				ON ta.id_agent = ag.agent_name 
			INNER JOIN
				sims_stats ss 
				ON ss.agent_id = ag.agents_id 
			LEFT JOIN
				report_date rp 
				ON ss.sim_id = rp.id_sim 
			INNER JOIN
				tarif tf 
				ON ss.tarif_id = tf.tarifs_id 
			INNER JOIN
				tariff_group tg 
				ON tf.tarifs_group = tg.id_group_tariff 
		WHERE
			ta.id_supervisors = sv.supervisors_id 
			AND ss.sim_id IS NOT NULL 
			AND 
			(
				@start_send_date IS NULL 
				OR ss.send_date >= @start_send_date 
			)
			AND 
			(
				@end_send_date IS NULL 
				OR ss.send_date <= @end_send_date 
			)
			AND 
			(
				@operator_id = 0 
				OR tf.operator_id = @operator_id 
			)
			AND 
			(
				@id_group_tarif = 0 
				OR tf.tarifs_group = @id_group_tarif 
			)
			AND 
			(
				@region_id = 0 
				OR ss.region_id = @region_id 
			)
			AND 
			(
				@start_reporting_period IS NULL 
				OR rp.reporting_date >= @start_reporting_period 
			)
			AND 
			(
				@end_reporting_period IS NULL 
				OR rp.reporting_date <= @end_reporting_period 
			)
		GROUP BY
			supervisors_id, sv_name 
	)
	SELECT
		sv.sv_name,
		sv_counts,
		activation_dates,
		percentage,
		moneys,
		ag_salarys,
		sv_salarys,
		purchase_prices,
		activation_costs,
		ag_bonuss 
	FROM
		supervisors sv 
		INNER JOIN
			cash ca 
			ON sv.sv_name = ca.sv_name 
		INNER JOIN
			fix_fee ff 
			ON sv.sv_name = ff.sv_name 
		INNER JOIN
			sims_counts sc 
			ON sv.sv_name = sc.sv_name 
	GROUP BY
		sv.sv_name,
		sv_counts,
		activation_dates,
		percentage,
		moneys,
		ag_salarys,
		sv_salarys,
		purchase_prices,
		activation_costs,
		ag_bonuss 
	ORDER BY
		sv.sv_name RETURN;
END;
GO
