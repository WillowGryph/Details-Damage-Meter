--[[ 
-------Details! Addon
-------Class Combat
	-------This file control combat class. A combat is a object wich hold combat attributes.
	-------The numeric part of table is compost by 4 indexes: [1] damage, [2] heal, [3] energies and [4] misc
]]

local _detalhes = 		_G._detalhes

--shortcuts
local combate =			_detalhes.combate
local container_combatentes = _detalhes.container_combatentes

--flags
local REACTION_HOSTILE =	0x00000040
local CONTROL_PLAYER =		0x00000100

--locals
local _setmetatable = setmetatable --> lua api
local _ipairs = ipairs --> lua api
local _pairs = pairs --> lua api
local _bit_band = bit.band --> lua api
local _date = date --> lua api
local _UnitName = UnitName --> wow api

--time hold
local _tempo = time()

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--[[ 	__call function, get an actor from current combat.
	combatTable ( index, actorName )
	index: container number [1] damage, [2] heal, [3] energies and [4] misc
	actorName: name of an actor (player, npc, pet, etc) --]]

_detalhes.call_combate = function (self, class_type, name)
	local container = self[class_type]
	local index_mapa = container._NameIndexTable [name]
	local actor = container._ActorTable [index_mapa]
	return actor
end

combate.__call = _detalhes.call_combate

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


--[[ Class Constructor ]]
function combate:NovaTabela (iniciada, _tabela_overall, combatId, ...)

	local esta_tabela = {true, true, true, true, true}
	
	esta_tabela [1] = container_combatentes:NovoContainer (_detalhes.container_type.CONTAINER_DAMAGE_CLASS, esta_tabela, combatId) --> Damage
	esta_tabela [2] = container_combatentes:NovoContainer (_detalhes.container_type.CONTAINER_HEAL_CLASS, esta_tabela, combatId) --> Healing
	esta_tabela [3] = container_combatentes:NovoContainer (_detalhes.container_type.CONTAINER_ENERGY_CLASS, esta_tabela, combatId) --> Energies
	esta_tabela [4] = container_combatentes:NovoContainer (_detalhes.container_type.CONTAINER_MISC_CLASS, esta_tabela, combatId) --> Misc
	esta_tabela [5] = container_combatentes:NovoContainer (_detalhes.container_type.CONTAINER_DAMAGE_CLASS, esta_tabela, combatId) --> place holder for customs
	
	_setmetatable (esta_tabela, combate)
	
	--> try discover if is a pvp combat
	local who_serial, who_name, who_flags, alvo_serial, alvo_name, alvo_flags = ...
	if (who_serial) then --> aqui ir� identificar o boss ou o oponente
		if (alvo_name and _bit_band (alvo_flags, REACTION_HOSTILE) ~= 0) then --> tentando pegar o inimigo pelo alvo
			esta_tabela.contra = alvo_name
			if (_bit_band (alvo_flags, CONTROL_PLAYER) ~= 0) then
				esta_tabela.pvp = true --> o alvo � da fac��o oposta ou foi dado mind control
			end
		elseif (who_name and _bit_band (who_flags, REACTION_HOSTILE) ~= 0) then --> tentando pegar o inimigo pelo who caso o mob � quem deu o primeiro hit
			esta_tabela.contra = who_name
			if (_bit_band (who_flags, CONTROL_PLAYER) ~= 0) then
				esta_tabela.pvp = true --> o who � da fac��o oposta ou foi dado mind control
			end
		else
			esta_tabela.pvp = true --> se ambos s�o friendly, seria isso um PVP entre jogadores da mesma fac��es?
		end
	end

	--> start/end time (duration)
	esta_tabela.data_fim = 0
	esta_tabela.data_inicio = 0
	
	--> record last event before dead
	esta_tabela.last_events_tables = {}
	
	--> frags
	esta_tabela.frags = {}
	esta_tabela.frags_need_refresh = false
	
	--> time data container
	esta_tabela.TimeData = _detalhes.timeContainer:CreateTimeTable()
	
	--> Skill cache (not used)
	esta_tabela.CombatSkillCache = {}

	-- a tabela sem o tempo de inicio � a tabela descartavel do inicio do addon
	if (iniciada) then
		esta_tabela.start_time = _tempo
		esta_tabela.end_time = nil
	else
		esta_tabela.start_time = 0
		esta_tabela.end_time = nil
	end

	-- o container ir� armazenar as classes de dano -- cria um novo container de indexes de seriais de jogadores --par�metro 1 classe armazenada no container, par�metro 2 = flag da classe
	esta_tabela[1].need_refresh = true
	esta_tabela[2].need_refresh = true
	esta_tabela[3].need_refresh = true
	esta_tabela[4].need_refresh = true
	esta_tabela[5].need_refresh = true
	
	if (_tabela_overall) then --> link � a tabela de combate do overall
		esta_tabela[1].shadow = _tabela_overall[1] --> diz ao objeto qual a shadow dele na tabela overall
		esta_tabela[2].shadow = _tabela_overall[2] --> diz ao objeto qual a shadow dele na tabela overall
		esta_tabela[3].shadow = _tabela_overall[3] --> diz ao objeto qual a shadow dele na tabela overall
		esta_tabela[4].shadow = _tabela_overall[4] --> diz ao objeto qual a shadow dele na tabela overall
	end

	-- abriga a tabela contendo o total de cada atributo
	-- esta_tabela.barra_total = barra_total:NovaBarra() 
	--> barra total movido para um simples membro do combate:
	esta_tabela.totals = {
		0, --> dano
		0, --> cura
		{--> e_energy
			mana = 0, --> mana
			e_rage = 0, --> rage
			e_energy = 0, --> energy (rogues cat)
			runepower = 0 --> runepower (dk)
		}, 
		{--> misc
			cc_break = 0, --> armazena quantas quebras de CC
			ress = 0, --> armazena quantos pessoas ele reviveu
			interrupt = 0, --> armazena quantos interrupt a pessoa deu
			dispell = 0, --> armazena quantos dispell esta pessoa recebeu
			dead = 0, --> armazena quantas vezes essa pessia morreu		
			cooldowns_defensive = 0 --> armazena quantos cooldowns a raid usou
		}
	}
	
	esta_tabela.totals_grupo = {
		0, --> dano
		0, --> cura
		{--> e_energy
			mana = 0, --> mana
			e_rage = 0, --> rage
			e_energy = 0, --> energy (rogues cat)
			runepower = 0 --> runepower (dk)
		}, 
		{--> misc
			cc_break = 0, --> armazena quantas quebras de CC
			ress = 0, --> armazena quantos pessoas ele reviveu
			interrupt = 0, --> armazena quantos interrupt a pessoa deu
			dispell = 0, --> armazena quantos dispell esta pessoa recebeu
			dead = 0, --> armazena quantas vezes essa oessia morreu		
			cooldowns_defensive = 0 --> armazena quantos cooldowns a raid usou
		}
	}

	return esta_tabela
end

function combate:GetTimeData (dataType)
	--if (not dataType) then
		return self.TimeData
	--end
end

function combate:TravarTempos()
	--� necess�rio travar o tempo em todos os atributos do combate.
	
	if (self [1]) then
		for _, jogador in _ipairs (self [1]._ActorTable) do --> damage
			if (jogador:Iniciar()) then -- retorna se ele esta com o dps ativo
				jogador:TerminarTempo()
				jogador:Iniciar (false) --trava o dps do jogador
				--jogador.last_events_table =  _detalhes:CreateActorLastEventTable()
			end
		end
	else
		--print ("combat [1] doesn't exist.")
	end
	if (self [2]) then
		for _, jogador in _ipairs (self [2]._ActorTable) do --> healing
			if (jogador:Iniciar()) then -- retorna se ele esta com o dps ativo
				jogador:TerminarTempo()
				jogador:Iniciar (false) --trava o dps do jogador
				--print ("travando o tempo de",jogador.nome, jogador.end_time)
				--jogador.last_events_table =  _detalhes:CreateActorLastEventTable()
			end
		end
	else
		--print ("combat [2] doesn't exist.")
	end
end

function combate:UltimaAcao (tempo)
	if (tempo) then
		self.last_event = tempo
	else
		return self.last_event
	end
end

function combate:seta_data (tipo)
	if (tipo == _detalhes._detalhes_props.DATA_TYPE_START) then
		self.data_inicio = _date ("%H:%M:%S")
	elseif (tipo == _detalhes._detalhes_props.DATA_TYPE_END) then
		self.data_fim = _date ("%H:%M:%S")
	end
end

function combate:GetActorList (container)
	return self [container]._ActorTable
end

function combate:GetCombatTime()
	if (self.end_time) then
		--print ("tem end time")
		return self.end_time - self.start_time
	elseif (self.start_time and _detalhes.in_combat) then
		--print ("tem start time e esta em combate")
		return _tempo - self.start_time
	else
		--print ("retornando zero")
		return 0
	end
end

function combate:GetTotal (attribute, subAttribute, onlyGroup)
	if (attribute == 1 or attribute == 2) then
		if (onlyGroup) then
			return self.totals_grupo [attribute]
		else
			return self.totals [attribute]
		end
		
	elseif (attribute == 3 or attribute == 4) then
		local subName = _detalhes:GetInternalSubAttributeName (attribute, subAttribute)
		if (onlyGroup) then
			return self.totals_grupo [attribute] [subName]
		else
			return self.totals [attribute] [subName]
		end
	end
	return 0
end

function combate:seta_tempo_decorrido()
	self.end_time = _tempo
end

function _detalhes.refresh:r_combate (tabela_combate, shadow)
	_setmetatable (tabela_combate, _detalhes.combate)
	tabela_combate.__index = _detalhes.combate
	tabela_combate.shadow = shadow
end

function _detalhes.clear:c_combate (tabela_combate)
	tabela_combate.__index = {}
	tabela_combate.__call = {}
	tabela_combate._combat_table = nil
	tabela_combate.shadow = nil
end

combate.__sub = function (overall, combate)

	--> foreach no dano
		for index, classe_damage in _ipairs (combate[1]._ActorTable) do
			local nome = classe_damage.nome
			local no_overall = overall[1]._ActorTable [overall[1]._NameIndexTable [nome]]
			no_overall = no_overall - classe_damage
			
			local alvos = classe_damage.targets
			for index, alvo in _ipairs (alvos._ActorTable) do 
				local alvo_overall = no_overall.targets._ActorTable [no_overall.targets._NameIndexTable [alvo.nome]]
				alvo_overall = alvo_overall - alvo
			end
			
			local habilidades = classe_damage.spell_tables
			for _spellid, habilidade in _pairs (habilidades._ActorTable) do 
				local habilidade_overall = no_overall.spell_tables._ActorTable [_spellid]
				habilidade_overall = habilidade_overall - habilidade
				
				local alvos = habilidade.targets
				for index, alvo in _ipairs (alvos._ActorTable) do 
					local alvo_overall = habilidade_overall.targets._ActorTable [habilidade_overall.targets._NameIndexTable [alvo.nome]]
					alvo_overall = alvo_overall - alvo
				end
			end
		end
		
	--> foreach na cura
		for index, classe_heal in _ipairs (combate[2]._ActorTable) do
			local nome = classe_heal.nome
			local no_overall = overall[2]._ActorTable [overall[2]._NameIndexTable [nome]]
			no_overall = no_overall - classe_heal
			
			local alvos = classe_heal.targets
			for index, alvo in _ipairs (alvos._ActorTable) do 
				local alvo_overall = no_overall.targets._ActorTable [no_overall.targets._NameIndexTable [alvo.nome]]
				alvo_overall = alvo_overall - alvo
			end
			
			local habilidades = classe_heal.spell_tables
			for _spellid, habilidade in _pairs (habilidades._ActorTable) do 
				local habilidade_overall = no_overall.spell_tables._ActorTable [_spellid]
				habilidade_overall = habilidade_overall - habilidade
				
				local alvos = habilidade.targets
				for index, alvo in _ipairs (alvos._ActorTable) do 
					local alvo_overall = habilidade_overall.targets._ActorTable [habilidade_overall.targets._NameIndexTable [alvo.nome]]
					alvo_overall = alvo_overall - alvo
				end
			end			
		end
		
	--> foreach na e_energy
		for index, classe_energy in _ipairs (combate[3]._ActorTable) do
			local nome = classe_energy.nome
			local no_overall = overall[3]._ActorTable [overall[3]._NameIndexTable [nome]]
			no_overall = no_overall - classe_energy
			
			local alvos = classe_energy.targets
			for index, alvo in _ipairs (alvos._ActorTable) do 
				local alvo_overall = no_overall.targets._ActorTable [no_overall.targets._NameIndexTable [alvo.nome]]
				alvo_overall = alvo_overall - alvo
			end
			
			local habilidades = classe_energy.spell_tables
			for _spellid, habilidade in _pairs (habilidades._ActorTable) do 
				local habilidade_overall = no_overall.spell_tables._ActorTable [_spellid]
				habilidade_overall = habilidade_overall - habilidade
				
				local alvos = habilidade.targets
				for index, alvo in _ipairs (alvos._ActorTable) do 
					local alvo_overall = habilidade_overall.targets._ActorTable [habilidade_overall.targets._NameIndexTable [alvo.nome]]
					alvo_overall = alvo_overall - alvo
				end
			end
		end
		
	--> foreach no misc
		for index, classe_misc in _ipairs (combate[4]._ActorTable) do
			local nome = classe_misc.nome
			local no_overall = overall[4]._ActorTable [overall[4]._NameIndexTable [nome]]
			no_overall = no_overall - classe_misc
			
			if (classe_misc.cooldowns_defensive) then
				local alvos = classe_misc.cooldowns_defensive_targets
				local habilidades = classe_misc.cooldowns_defensive_spell_tables
				
				for index, alvo in _ipairs (alvos._ActorTable) do
					local alvo_overall = no_overall.cooldowns_defensive_targets._ActorTable [no_overall.cooldowns_defensive_targets._NameIndexTable [alvo.nome]]
					alvo_overall = alvo_overall - alvo
				end
				
				for _spellid, habilidade in _pairs (habilidades._ActorTable) do 
					local habilidade_overall = no_overall.cooldowns_defensive_spell_tables._ActorTable [_spellid]
					habilidade_overall = habilidade_overall - habilidade
					
					local alvos = habilidade.targets
					for index, alvo in _ipairs (alvos._ActorTable) do 
						local alvo_overall = habilidade_overall.targets._ActorTable [habilidade_overall.targets._NameIndexTable [alvo.nome]]
						alvo_overall = alvo_overall - alvo
					end
				end
			end
			
			if (classe_misc.interrupt) then
				local alvos = classe_misc.interrupt_targets
				local habilidades = classe_misc.interrupt_spell_tables
				
				for index, alvo in _ipairs (alvos._ActorTable) do
					local alvo_overall = no_overall.interrupt_targets._ActorTable [no_overall.interrupt_targets._NameIndexTable [alvo.nome]]
					alvo_overall = alvo_overall - alvo
				end
				
				for _spellid, habilidade in _pairs (habilidades._ActorTable) do 
					local habilidade_overall = no_overall.interrupt_spell_tables._ActorTable [_spellid]
					habilidade_overall = habilidade_overall - habilidade
					
					local alvos = habilidade.targets
					for index, alvo in _ipairs (alvos._ActorTable) do 
						local alvo_overall = habilidade_overall.targets._ActorTable [habilidade_overall.targets._NameIndexTable [alvo.nome]]
						alvo_overall = alvo_overall - alvo
					end
				end
			end

			if (classe_misc.ress) then
				local alvos = classe_misc.ress_targets
				local habilidades = classe_misc.ress_spell_tables
				
				for index, alvo in _ipairs (alvos._ActorTable) do
					local alvo_overall = no_overall.ress_targets._ActorTable [no_overall.ress_targets._NameIndexTable [alvo.nome]]
					alvo_overall = alvo_overall - alvo
				end
				
				for _spellid, habilidade in _pairs (habilidades._ActorTable) do 
					local habilidade_overall = no_overall.ress_spell_tables._ActorTable [_spellid]
					habilidade_overall = habilidade_overall - habilidade
					
					local alvos = habilidade.targets
					for index, alvo in _ipairs (alvos._ActorTable) do 
						local alvo_overall = habilidade_overall.targets._ActorTable [habilidade_overall.targets._NameIndexTable [alvo.nome]]
						alvo_overall = alvo_overall - alvo
					end
				end
			end	

			if (classe_misc.dispell) then
				local alvos = classe_misc.dispell_targets
				local habilidades = classe_misc.dispell_spell_tables
				
				for index, alvo in _ipairs (alvos._ActorTable) do
					local alvo_overall = no_overall.dispell_targets._ActorTable [no_overall.dispell_targets._NameIndexTable [alvo.nome]]
					alvo_overall = alvo_overall - alvo
				end
				
				for _spellid, habilidade in _pairs (habilidades._ActorTable) do 
					local habilidade_overall = no_overall.dispell_spell_tables._ActorTable [_spellid]
					habilidade_overall = habilidade_overall - habilidade
					
					local alvos = habilidade.targets
					for index, alvo in _ipairs (alvos._ActorTable) do 
						local alvo_overall = habilidade_overall.targets._ActorTable [habilidade_overall.targets._NameIndexTable [alvo.nome]]
						alvo_overall = alvo_overall - alvo
					end
				end
			end

			if (classe_misc.cc_break) then
				local alvos = classe_misc.cc_break_targets
				local habilidades = classe_misc.cc_break_spell_tables
				
				for index, alvo in _ipairs (alvos._ActorTable) do
					local alvo_overall = no_overall.cc_break_targets._ActorTable [no_overall.cc_break_targets._NameIndexTable [alvo.nome]]
					alvo_overall = alvo_overall - alvo
				end
				
				for _spellid, habilidade in _pairs (habilidades._ActorTable) do 
					local habilidade_overall = no_overall.cc_break_spell_tables._ActorTable [_spellid]
					habilidade_overall = habilidade_overall - habilidade
					
					local alvos = habilidade.targets
					for index, alvo in _ipairs (alvos._ActorTable) do 
						local alvo_overall = habilidade_overall.targets._ActorTable [habilidade_overall.targets._NameIndexTable [alvo.nome]]
						alvo_overall = alvo_overall - alvo
					end
				end
			end
		
		end
	
	--> diminui o total
	overall.totals[1] = overall.totals[1] - combate.totals[1]
	overall.totals[2] = overall.totals[2] - combate.totals[2]
	
	overall.totals[3].mana = overall.totals[3].mana - combate.totals[3].mana
	overall.totals[3].e_rage = overall.totals[3].e_rage - combate.totals[3].e_rage
	overall.totals[3].e_energy = overall.totals[3].e_energy - combate.totals[3].e_energy
	overall.totals[3].runepower = overall.totals[3].runepower - combate.totals[3].runepower
	
	overall.totals[4].cc_break = overall.totals[4].cc_break - combate.totals[4].cc_break
	overall.totals[4].ress = overall.totals[4].ress - combate.totals[4].ress
	overall.totals[4].interrupt = overall.totals[4].interrupt - combate.totals[4].interrupt
	overall.totals[4].dispell = overall.totals[4].dispell - combate.totals[4].dispell
	overall.totals[4].dead = overall.totals[4].dead - combate.totals[4].dead
	overall.totals[4].cooldowns_defensive = overall.totals[4].cooldowns_defensive - combate.totals[4].cooldowns_defensive
	
	overall.totals_grupo[1] = overall.totals_grupo[1] - combate.totals_grupo[1]
	overall.totals_grupo[2] = overall.totals_grupo[2] - combate.totals_grupo[2]
	
	overall.totals_grupo[3].mana = overall.totals_grupo[3].mana - combate.totals_grupo[3].mana
	overall.totals_grupo[3].e_rage = overall.totals_grupo[3].e_rage - combate.totals_grupo[3].e_rage
	overall.totals_grupo[3].e_energy = overall.totals_grupo[3].e_energy - combate.totals_grupo[3].e_energy
	overall.totals_grupo[3].runepower = overall.totals_grupo[3].runepower - combate.totals_grupo[3].runepower
	
	overall.totals_grupo[4].cc_break = overall.totals_grupo[4].cc_break - combate.totals_grupo[4].cc_break
	overall.totals_grupo[4].ress = overall.totals_grupo[4].ress - combate.totals_grupo[4].ress
	overall.totals_grupo[4].interrupt = overall.totals_grupo[4].interrupt - combate.totals_grupo[4].interrupt
	overall.totals_grupo[4].dispell = overall.totals_grupo[4].dispell - combate.totals_grupo[4].dispell
	overall.totals_grupo[4].dead = overall.totals_grupo[4].dead - combate.totals_grupo[4].dead
	overall.totals_grupo[4].cooldowns_defensive = overall.totals_grupo[4].cooldowns_defensive - combate.totals_grupo[4].cooldowns_defensive
	
	for fragName, fragAmount in pairs (combate.frags) do 
		if (fragAmount and overall.frags [fragName]) then --> not sure why 
			overall.frags [fragName] = overall.frags [fragName] - fragAmount
		end
	end
	overall.frags_need_refresh = true
	
	return overall
end

function _detalhes:UpdateCombat()
	_tempo = _detalhes._tempo
end
