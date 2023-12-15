USE [sim_stats]
GO
/****** Object:  StoredProcedure [dbo].[income_procedure]    Script Date: 15.12.2023 10:01:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[income_procedure] @start_send_date DATE = NULL, @end_send_date DATE = NULL, @start_activation_date DATE = NULL, @end_activation_date DATE = NULL, @operator_id INT = 0, @id_group_tarif INT = 0, @region_id INT = 0, @start_reporting_period DATE = NULL, @end_reporting_period DATE = NULL, @sv_name NVARCHAR(300) = null AS 
BEGIN
	SET
		nocount 
		ON;
WITH report_date AS 
(
	SELECT
		id_sim,
		string_agg(CONVERT(NVARCHAR(MAX), MONEY), '|') AS MONEY,
		string_agg(CONVERT(NVARCHAR(MAX), reporting_period), '|') AS reporting_date 
	FROM
		pay_bilane 
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
		LEFT JOIN
			pay_bilane pb 
			ON ss.sim_id = pb.id_sim 
		LEFT JOIN
			tarif tf 
			ON ss.tarif_id = tf.tarifs_id 
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
		AND 
		(
			@sv_name IS NULL 
			OR sv.sv_name = @sv_name
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
		AND 
		(
			@sv_name IS NULL 
			OR sv.sv_name = @sv_name
		)
	GROUP BY
		sv.sv_name 
)
, sims_counts AS 
(
	SELECT
		sv_name,
		COUNT( 
		CASE
			WHEN
				send_date IS NOT NULL 
			THEN
				send_date 
		END
) AS sv_counts, COUNT( 
		CASE
			WHEN
				activation_date IS NOT NULL 
			THEN
				activation_date 
		END
) AS activation_dates, CAST(COUNT(activation_date) * 100.0 / COUNT(send_date) AS DECIMAL(10, 2)) AS percentage, round(SUM( 
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
		AND 
		(
			@sv_name IS NULL 
			OR sv.sv_name = @sv_name
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
	sv.sv_name 
RETURN;
END;
